{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Traversal where

import Control.DeepSeq (NFData)
import Control.Monad (foldM, replicateM)
import Data.List (foldl')
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import GHC.Generics (Generic)
import System.Random.Stateful

data Tree
  = Atom {-# UNPACK #-} !Int {-# UNPACK #-} !String
  | Object {-# UNPACK #-} !Int !(Map String Tree)
  deriving (Show, Eq, Generic, NFData)

pretrav :: (Tree -> Tree) -> Tree -> Tree
pretrav f t =
  let t' = f t
   in case t' of
        Atom{} -> t'
        Object vers ts -> Object vers $ Map.map (pretrav f) ts

pretravM :: (Monad m) => (Tree -> m Tree) -> Tree -> m Tree
pretravM f t = do
  t' <- f t
  case t' of
    Atom{} -> return t'
    Object vers ts -> do
      ts' <- mapM (pretravM f) ts
      return $ Object vers ts'

access :: [String] -> (Tree -> Tree) -> Tree -> Tree
access [] f t = f t
access (k : ks) f (Object vers ts) = Object vers $ Map.alter modifyChild k ts
 where
  modifyChild Nothing = error "Invalid path to access"
  modifyChild (Just child) = Just $ access ks f child
access _ _ _ = error "Invalid path to access"

accessM :: (Monad m) => [String] -> (Tree -> m Tree) -> Tree -> m Tree
accessM [] f t = f t
accessM (k : ks) f (Object vers ts) = case Map.lookup k ts of
  Nothing -> error "Invalid path to access"
  Just child -> do
    child' <- accessM ks f child
    let ts' = Map.insert k child' ts
    return $ Object vers ts'
accessM _ _ _ = error "Invalid path to access"

data Zipper = Zipper
  { focus :: !Tree
  , breadcrumbs :: [Crumb]
  }
  deriving (Show, Eq, Generic, NFData)

type Move = Zipper -> Zipper

data Crumb = Crumb
  { holeKey :: !String
  , storedVers :: !Int
  , siblings :: !(Map String Tree)
  }
  deriving (Show, Eq, Generic, NFData)

emptyZipper :: Tree -> Zipper
emptyZipper t = Zipper t []

modifyZipper :: (Tree -> Tree) -> Zipper -> Zipper
modifyZipper f (Zipper t bs) = Zipper (f t) bs

modifyZipperM :: (Monad m) => (Tree -> m Tree) -> Zipper -> m Zipper
modifyZipperM f (Zipper t bs) = do
  t' <- f t
  return $ Zipper t' bs

goDown :: String -> Zipper -> Zipper
goDown k (Zipper (Object vers ts) bs)
  | (Just child, siblings') <- Map.updateLookupWithKey (\_ _ -> Nothing) k ts =
      Zipper child (Crumb k vers siblings' : bs)
goDown k (Zipper f _) = error $ "Cannot go to child '" ++ k ++ "' of tree: " ++ show f

goUp :: Zipper -> Zipper
goUp (Zipper t (Crumb key vers siblings' : bs)) = Zipper (Object vers (Map.insert key t siblings')) bs
goUp (Zipper _ []) = error "Already at the top"

closeZipper :: Zipper -> Tree
closeZipper (Zipper t []) = t
closeZipper z = closeZipper (goUp z)

stay :: Move
stay = id

pretravWithZipper :: (Tree -> Tree) -> Zipper -> Zipper
pretravWithZipper f z =
  let z' = modifyZipper f z
   in case focus z' of
        Atom{} -> z'
        Object _ ts -> foldl' (\acc k -> goUp (pretravWithZipper f (goDown k acc))) z' (Map.keys ts)

pretravWithZipperM :: (Monad m) => (Tree -> m Tree) -> Zipper -> m Zipper
pretravWithZipperM f z = do
  z' <- modifyZipperM f z
  case focus z' of
    Atom{} -> return z'
    Object _ ts -> foldM (\acc k -> do z'' <- pretravWithZipperM f (goDown k acc); return $ goUp z'') z' (Map.keys ts)

-- == Test Tree and Modification Workloads ==

buildTree :: Int -> Int -> Tree
buildTree depth width = buildNode 0 depth
 where
  -- Giving each node a distinct version prevents GHC from sharing identical
  -- subtrees under -O2. The benchmark should contain a tree, not a DAG.
  buildNode nodeId 0 = Atom nodeId ""
  buildNode nodeId remainingDepth =
    Object nodeId $
      Map.fromList
        [ (show i, buildNode (nodeId * width + i + 1) (remainingDepth - 1))
        | i <- [0 .. width - 1]
        ]

testPretrav :: Tree -> Tree
testPretrav = pretrav increaseVers

genRandomPaths :: Int -> Int -> Int -> IO [[String]]
genRandomPaths depth width n = do
  gen <- newIOGenM (mkStdGen benchmarkSeed)
  replicateM n (genRandomPath gen depth width)

benchmarkSeed :: Int
benchmarkSeed = 20260716

genRandomPath :: IOGenM StdGen -> Int -> Int -> IO [String]
genRandomPath gen depth width = do
  m <- uniformRM (1, depth) gen
  mapM (\_ -> show <$> uniformRM (0, width - 1) gen) [1 .. m]

genLocalWalkPaths :: Int -> Int -> Int -> Int -> IO [[String]]
genLocalWalkPaths depth width maxSteps n = do
  gen <- newIOGenM (mkStdGen benchmarkSeed)
  (_, res) <-
    foldM
      ( \(prevPath, paths) _ -> do
          newPath <- stepLocalWalk gen depth width maxSteps prevPath
          return (newPath, newPath : paths)
      )
      ([], [])
      [1 .. n]
  return (reverse res)

stepLocalWalk :: IOGenM StdGen -> Int -> Int -> Int -> [String] -> IO [String]
stepLocalWalk gen maxDepth width maxSteps prevPath
  | null prevPath = genRandomPath gen maxDepth width
  | length prevPath == maxDepth = do
      upSteps <- uniformRM (1, min maxSteps maxDepth) gen
      return $ take (maxDepth - upSteps) prevPath
  | otherwise = do
      let depth = length prevPath
      direction <- uniformRM (0 :: Int, 1) gen
      if direction == 0
        then do
          upSteps <- uniformRM (1, min maxSteps depth) gen
          return $ take (depth - upSteps) prevPath
        else do
          steps <- uniformRM (1, min maxSteps (maxDepth - depth)) gen
          newKeys <- replicateM steps (show <$> uniformRM (0, width - 1) gen)
          return $ prevPath ++ newKeys

increaseVers :: Tree -> Tree
increaseVers (Atom n s) = Atom (n + 1) s
increaseVers (Object n ts) = Object (n + 1) ts

testTreeModify :: [[String]] -> Tree -> Tree
testTreeModify paths t = foldl' (\acc path -> access path increaseVers acc) t paths

data OperationKind = ReadOperation | WriteOperation
  deriving (Show, Eq, Generic, NFData)

data Operation = Operation
  { operationKind :: !OperationKind
  , operationPath :: ![String]
  }
  deriving (Show, Eq, Generic, NFData)

genOperations :: [[String]] -> IO [Operation]
genOperations = mapM $ \path -> do
  kind <- uniformRM (0 :: Int, 1) globalStdGen
  return $ Operation (if kind == 0 then ReadOperation else WriteOperation) path

lookupTree :: [String] -> Tree -> Tree
lookupTree [] t = t
lookupTree (k : ks) (Object _ ts) = case Map.lookup k ts of
  Nothing -> error "Invalid path to read"
  Just child -> lookupTree ks child
lookupTree _ _ = error "Invalid path to read"

treeVersion :: Tree -> Int
treeVersion (Atom vers _) = vers
treeVersion (Object vers _) = vers

-- Checksums make every read observable to the benchmark and prevent it from
-- being discarded as an unused pure computation.
testTreeLookup :: [[String]] -> Tree -> Int
testTreeLookup paths t =
  foldl' (\ !checksum path -> checksum + treeVersion (lookupTree path t)) 0 paths

data ZipperStep = StepUp | StepDown !String
  deriving (Show, Eq, Generic, NFData)

zipperStepsBetween :: [String] -> [String] -> [ZipperStep]
zipperStepsBetween prevPath newPath =
  replicate ups StepUp ++ map StepDown downKeys
 where
  commonPrefixLength = length $ takeWhile (uncurry (==)) (zip prevPath newPath)
  ups = length prevPath - commonPrefixLength
  downKeys = drop commonPrefixLength newPath

convertZipperPaths :: [[String]] -> [[ZipperStep]]
convertZipperPaths paths = reverse converted
 where
  (_, converted) = foldl' convert ([], []) paths
  convert (prevPath, acc) newPath =
    (newPath, zipperStepsBetween prevPath newPath : acc)

convertZipperAccess :: [[String]] -> [Move]
convertZipperAccess = map applyZipperSteps . convertZipperPaths

data ZipperOperation = ZipperOperation !OperationKind ![ZipperStep]
  deriving (Show, Eq, Generic, NFData)

convertZipperOperations :: [Operation] -> [ZipperOperation]
convertZipperOperations operations = reverse converted
 where
  (_, converted) = foldl' convert ([], []) operations

  convert (prevPath, acc) (Operation kind newPath) =
    (newPath, ZipperOperation kind (zipperStepsBetween prevPath newPath) : acc)

applyZipperSteps :: [ZipperStep] -> Zipper -> Zipper
applyZipperSteps steps z = foldl' step z steps
 where
  step acc StepUp = goUp acc
  step acc (StepDown key) = goDown key acc

testPretravWithZipper :: Zipper -> Zipper
testPretravWithZipper = pretravWithZipper increaseVers

testZipperModify :: [Move] -> Zipper -> Zipper
testZipperModify moves z = foldl' (\acc move -> modifyZipper increaseVers (move acc)) z moves

testZipperModifySteps :: [[ZipperStep]] -> Zipper -> Tree
testZipperModifySteps moves z =
  closeZipper $ foldl' (\acc move -> modifyZipper increaseVers (applyZipperSteps move acc)) z moves

testZipperLookup :: [[ZipperStep]] -> Zipper -> Int
testZipperLookup moves z = snd $ foldl' step (z, 0) moves
 where
  step (!acc, !checksum) move =
    let !moved = applyZipperSteps move acc
     in (moved, checksum + treeVersion (focus moved))
