---
layout: post
title:  "Benchmarking Zippers in Haskell"
date:   2026-07-16
categories: Haskell
mermaid: true
---

In the previous post, we explored zippers and their applications in functional programming. In this post, we benchmark their performance against a root-based approach.

## Two Approaches

We define a simple tree data structure and the naive root-based approach for traversing and modifying the tree.

```haskell
data Tree
  = Atom !Int !String
  | Object !Int !(Map String Tree)
  deriving (Show, Eq, Generic, NFData)

access :: [String] -> (Tree -> Tree) -> Tree -> Tree
access [] f t = f t
access (k : ks) f (Object vers ts) = Object vers $ Map.alter modifyChild k ts
 where
  modifyChild Nothing = error "Invalid path to access"
  modifyChild (Just child) = Just $ access ks f child
access _ _ _ = error "Invalid path to access"
```

Then we implement the zipper data structure and its operations for traversing and modifying the tree.

```haskell
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

goDown :: String -> Zipper -> Zipper
goDown k (Zipper (Object vers ts) bs)
  | (Just child, siblings') <- Map.updateLookupWithKey (\_ _ -> Nothing) k ts =
      Zipper child (Crumb k vers siblings' : bs)
goDown k (Zipper f _) = error $ "Cannot go to child '" ++ k ++ "' of tree: " ++ show f

goUp :: Zipper -> Zipper
goUp (Zipper t (Crumb key vers siblings' : bs)) = Zipper (Object vers (Map.insert key t siblings')) bs
goUp (Zipper _ []) = error "Already at the top"
```

## Benchmark Design

Each benchmark performs 100,000 operations. Three full trees are generated with the following shapes:

| Depth × width |     nodes | Children per Map |
| ------------- | --------: | ---------------- |
| 5 × 16        | 1,118,481 | 16               |
| 10 × 4        | 1,398,101 | 4                |
| 20 × 2        | 2,097,151 | 2                |

Here, depth counts edges from the root. All three trees have exactly 1,048,576 leaves, but their shapes differ.

The workloads are:

1. **Random lookup.** Choose the path depth uniformly from 1 through the maximum depth, then choose every key uniformly.
   Read the node's integer into a checksum.
2. **Random edit.** Generate paths in the same way, then increment the node's integer. Both `Atom` and `Object` are updated.
3. **Local edit.** Start at a random path, then move one or two levels either up or down before each edit. A leaf moves
   up; after visiting the root, the next path restarts at a random location. For example, the path sequence `a/b/c ->
   a/b -> a/b/d/e`.

The local targets are actually deeper on average than the random targets. Their advantage comes from shorter travel,
not from choosing shallower nodes.

### Measurement Details

These results are based on running the benchmarks on a MacBook Air M4 with 24 GB of RAM, using the following environment:

- arm64, macOS 26.3.1
- GHC 9.6.7, Cabal 3.12.1.0
- Criterion 1.6.5.0
- containers 0.6.7, random 1.3.1
- fixed seed 20260716

The test program is compiled with `ghc -O2`. 

Trees, paths, and relative zipper moves are generated and fully evaluated outside the timed region. Update benchmarks
use `whnf`: the strict tree fields and `Data.Map.Strict` force each update, without adding an
unrelated traversal of the entire result. The zipper is returned to the root at the end of each batch, so both update
implementations produce the same `Tree`.

The commands are:

```console
cabal run zippers-time
```

## Timing Results

Each time is Criterion’s mean for the entire 100,000-operation batch. Values are shown as root time / zipper time — faster implementation and speedup. The speedup is the slower time divided by the faster time; for example, root 4.30× means the zipper took 4.30 times as long as the root implementation.

| Tree   | Random lookup                  | Random edit                    | Local edit                      |
| ------ | ------------------------------ | ------------------------------ | ------------------------------- |
| 5 × 16 | 22.45 / 96.45 ms — root 4.30×  | 63.13 / 98.12 ms — root 1.55×  | 33.73 / 30.22 ms — zipper 1.12× |
| 10 × 4 | 20.37 / 84.52 ms — root 4.15×  | 56.73 / 88.22 ms — root 1.56×  | 29.99 / 17.04 ms — zipper 1.76× |
| 20 × 2 | 38.87 / 121.25 ms — root 3.12× | 94.62 / 122.20 ms — root 1.29× | 30.88 / 9.23 ms — zipper 3.34×  |

## Analysis of the Results

A root lookup performs one `Map.lookup` at each level and allocates very little. This Map-based zipper, on the other hand,
must allocate memory for each move. This makes the zipper slower for random lookups.

Random edits narrow the gap because the root implementation must also rebuild every map on the path. The zipper is still
slower because it travels farther than the root implementation: it usually needs to climb close to the root before
moving to the next target. The path between two random targets is usually longer than the path from the root to either target.

For the local workload, the root implementation starts over for every edit even though consecutive paths share most of
their prefix. On the deepest tree, the root still traverses a long path for each edit, while the zipper moves only about 1.5 edges between nearby targets. The root implementation is also much faster on local edits than on random edits. This likely reflects better CPU-cache locality because consecutive operations revisit the same branches.

The increasing advantage is not caused by depth in isolation: these test shapes become narrower as they become deeper.
Smaller maps make per-level operations cheaper for both implementations.

## Practical Takeaway

- Use direct root traversal for isolated or scattered operations, especially reads; for such workloads, a zipper is not worth the overhead.
- For a batch of nearby edits, keep the zipper open between edits and convert it back to a complete tree only after the batch.

The [complete benchmark source](https://github.com/jzhonx/jzhonx.github.io/tree/main/code/zippers_perf) is available in
the repository.
