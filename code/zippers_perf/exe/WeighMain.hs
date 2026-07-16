module Main where

import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Traversal (
    buildTree,
    convertZipperPaths,
    emptyZipper,
    genLocalWalkPaths,
    genRandomPaths,
    testPretrav,
    testPretravWithZipper,
    testTreeLookup,
    testTreeModify,
    testZipperLookup,
    testZipperModifySteps,
 )
import Weigh (Weigh, func', mainWith)

main :: IO ()
main = do
    benchmarkGroups <- mapM (uncurry benchmarksForTree) treeDimensions
    mainWith $ sequence_ benchmarkGroups

treeDimensions :: [(Int, Int)]
treeDimensions =
    [ (5, 16)
    , (10, 4)
    , (20, 2)
    ]

benchmarksForTree :: Int -> Int -> IO (Weigh ())
benchmarksForTree depth width = do
    let numPaths = 100000
        name benchmarkName =
            "depth=" ++ show depth ++ ",width=" ++ show width ++ ": " ++ benchmarkName

    testTree <- evaluate $ force $ buildTree depth width
    testZipper <- evaluate $ force $ emptyZipper testTree

    randomPaths <- genRandomPaths depth width numPaths >>= evaluate . force
    randomMoves <- evaluate $ force $ convertZipperPaths randomPaths

    localWalkPaths <- genLocalWalkPaths depth width 2 numPaths >>= evaluate . force
    localWalkMoves <- evaluate $ force $ convertZipperPaths localWalkPaths

    return $ do
        func' (name "pretrav") testPretrav testTree
        func' (name "pretravWithZipper") testPretravWithZipper testZipper
        func' (name "randomLookup") (testTreeLookup randomPaths) testTree
        func' (name "randomLookupWithZipper") (testZipperLookup randomMoves) testZipper
        func' (name "randomModify") (testTreeModify randomPaths) testTree
        func' (name "randomModifyWithZipper") (testZipperModifySteps randomMoves) testZipper
        func' (name "localWalkModify") (testTreeModify localWalkPaths) testTree
        func' (name "localWalkModifyWithZipper") (testZipperModifySteps localWalkMoves) testZipper
