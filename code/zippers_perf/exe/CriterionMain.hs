module Main where

import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Criterion.Main (Benchmark, bench, bgroup, defaultMain, env, nf, whnf)
import Traversal (
    Tree,
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

main :: IO ()
main = defaultMain $ map (uncurry benchmarksForTree) treeDimensions

treeDimensions :: [(Int, Int)]
treeDimensions =
    [ (5, 16)
    , (10, 4)
    , (20, 2)
    ]

benchmarksForTree :: Int -> Int -> Benchmark
benchmarksForTree depth width =
    bgroup ("depth=" ++ show depth ++ ",width=" ++ show width) $
        -- traversalBenchmarks depth width
        [ pathBenchmarks
            depth
            width
            "random"
            True
            (genRandomPaths depth width numPaths)
        , pathBenchmarks
            depth
            width
            "localWalk"
            False
            (genLocalWalkPaths depth width maxLocalWalkSteps numPaths)
        ]
  where
    numPaths = 100000
    maxLocalWalkSteps = 2

traversalBenchmarks :: Int -> Int -> [Benchmark]
traversalBenchmarks depth width =
    [ env (buildTestTree depth width) $ \testTree ->
        bench "pretrav" $ nf testPretrav testTree
    , env (buildTestTree depth width) $ \testTree ->
        bench "pretravWithZipper" $ nf testPretravWithZipper (emptyZipper testTree)
    ]

pathBenchmarks :: Int -> Int -> String -> Bool -> IO [[String]] -> Benchmark
pathBenchmarks depth width workloadName includeLookup genPaths =
    bgroup workloadName $
        lookupBenchmarks
            ++ [ env setupTreeAndPaths $ \ ~(testTree, paths) ->
                    bench "modify" $ whnf (testTreeModify paths) testTree
               , env setupTreeAndMoves $ \ ~(testTree, moves) ->
                    bench "modifyWithZipper" $ whnf (testZipperModifySteps moves) (emptyZipper testTree)
               ]
  where
    lookupBenchmarks
        | includeLookup =
            [ env setupTreeAndPaths $ \ ~(testTree, paths) ->
                bench "lookup" $ nf (testTreeLookup paths) testTree
            , env setupTreeAndMoves $ \ ~(testTree, moves) ->
                bench "lookupWithZipper" $ nf (testZipperLookup moves) (emptyZipper testTree)
            ]
        | otherwise = []

    setupTreeAndPaths = do
        testTree <- buildTestTree depth width
        paths <- genPaths >>= evaluate . force
        return (testTree, paths)

    setupTreeAndMoves = do
        (testTree, paths) <- setupTreeAndPaths
        moves <- evaluate $ force $ convertZipperPaths paths
        return (testTree, moves)

buildTestTree :: Int -> Int -> IO Tree
buildTestTree depth width = evaluate $ force $ buildTree depth width
