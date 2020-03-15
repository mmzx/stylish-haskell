--------------------------------------------------------------------------------
module Language.Haskell.Stylish.Tests
    ( tests
    ) where


--------------------------------------------------------------------------------
import           Data.List                           (sort)
import           System.Directory                    (createDirectory,
                                                      createDirectoryIfMissing)
import           System.FilePath                     (normalise, (</>))
import           Test.Framework                      (Test, testGroup)
import           Test.Framework.Providers.HUnit      (testCase)
import           Test.HUnit                          (Assertion, (@?=))


--------------------------------------------------------------------------------
import           Language.Haskell.Stylish
import           Language.Haskell.Stylish.Tests.Util


--------------------------------------------------------------------------------
tests :: Test
tests = testGroup "Language.Haskell.Stylish.Tests"
    [ testCase "case 01" case01
    , testCase "case 02" case02
    , testCase "case 03" case03
    , testCase "case 04" case04
    , testCase "case 05" case05
    , testCase "case 06" case06
    , testCase "case 07" case07
    , testCase "case 08" case08
    , testCase "case 09" case09
    , testCase "case 10" case10
    , testCase "case 11" case11
    , testCase "case 12" case12
    ]


--------------------------------------------------------------------------------
case01 :: Assertion
case01 = (@?= result) =<< format Nothing Nothing input
  where
    input = "module Herp where\ndata Foo = Bar | Baz { baz :: Int }"
    result = Right $ lines input


--------------------------------------------------------------------------------
case02 :: Assertion
case02 = withTestDirTree $ do
    writeFile "test-config.yaml" $ unlines
        [ "steps:"
        , "  - records:"
        , "      equals: \"indent 2\""
        , "      first_field: \"indent 2\""
        , "      field_comment: 2"
        , "      deriving: 2"
        ]

    actual <- format (Just $ ConfigPath "test-config.yaml") Nothing input
    actual @?= result
  where
    input = "module Herp where\ndata Foo = Bar | Baz { baz :: Int }"
    result = Right [ "module Herp where"
                   , "data Foo"
                   , "  = Bar"
                   , "  | Baz"
                   , "      { baz :: Int"
                   , "      }"
                   ]

--------------------------------------------------------------------------------
case03 :: Assertion
case03 = withTestDirTree $ do
    writeFile "test-config.yaml" $ unlines
        [ "steps:"
        , "  - records:"
        , "      equals: \"same_line\""
        , "      first_field: \"same_line\""
        , "      field_comment: 2"
        , "      deriving: 2"
        ]

    actual <- format (Just $ ConfigPath "test-config.yaml") Nothing input
    actual @?= result
  where
    input = unlines [ "module Herp where"
                    , "data Foo"
                    , "  = Bar"
                    , "  | Baz"
                    , "      { baz :: Int"
                    , "      }"
                    ]
    result = Right [ "module Herp where"
                   , "data Foo = Bar"
                   , "         | Baz { baz :: Int"
                   , "               }"
                   ]

--------------------------------------------------------------------------------
case04 :: Assertion
case04 = (@?= result) =<< format Nothing (Just fileLocation) input
  where
    fileLocation = "directory/File.hs"
    input = "module Herp"
    result = Left $
      "Language.Haskell.Stylish.Parse.parseModule: could not parse " <>
      fileLocation <>
      ": ParseFailed (SrcLoc \"<unknown>.hs\" 2 1) \"Parse error: EOF\""


--------------------------------------------------------------------------------
-- | When providing current dir including folders and files.
case05 :: Assertion
case05 = withTestDirTree $ do
  createDirectory aDir >> writeFile c fileCont
  mapM_ (flip writeFile fileCont) fs
  result <- findHaskellFiles False input toExclude
  sort result @?= (sort $ map normalise expected)
  where
    input    = c : fs
    fs = ["b.hs", "a.hs"]
    c  = aDir </> "c.hs"
    aDir     = "aDir"
    expected = ["a.hs", "b.hs", c]
    fileCont = ""
    toExclude = Nothing

--------------------------------------------------------------------------------
-- | When the input item is not file, do not recurse it.
case06 :: Assertion
case06 = withTestDirTree $ do
  mapM_ (flip writeFile "") input
  result <- findHaskellFiles False input toExclude
  result @?= expected
  where
    input    = ["b.hs"]
    expected = map normalise input
    toExclude = Nothing

--------------------------------------------------------------------------------
-- | Empty input should result in empty output.
case07 :: Assertion
case07 = withTestDirTree $ do
  mapM_ (flip writeFile "") input
  result <- findHaskellFiles False input toExclude
  result @?= expected
  where
    input    = []
    expected = input
    toExclude = Nothing

--------------------------------------------------------------------------------
-- | stylish-haskell a.hs b.hs .git
case08 :: Assertion
case08 = do
  let result = excludeFiles input toExclude
  result @?= expected
  where
    input = ["./a.hs", "b.hs", ".git"]
    toExclude = Nothing
    expected = input

--------------------------------------------------------------------------------
-- | stylish-haskell -e .git a.hs b.hs ./.git
case09 :: Assertion
case09 = do
  let result = excludeFiles input toExclude
  result @?= expected
  where
    input = ["a.hs", "b.hs", "./.git"]
    toExclude = Just $ [".git"]
    expected = ["a.hs", "b.hs"]

--------------------------------------------------------------------------------
-- | stylish-haskell -e .git -e a/b/c.hs a.hs b.hs .git
case10 :: Assertion
case10 = do
  let result = excludeFiles input toExclude
  result @?= expected
  where
    input = ["a.hs", "b.hs", ".git"]
    toExclude = Just $ [".git", "a/b/c.hs"]
    expected = ["a.hs", "b.hs"]

--------------------------------------------------------------------------------
-- | stylish-haskell -e .git -e a/b/ a.hs b.hs .git a/b/c.hs
case11 :: Assertion
case11 = do
  let result = excludeFiles input toExclude
  result @?= expected
  where
    input = ["a.hs", "b.hs", ".git", "a/b/c.hs"]
    toExclude = Just $ [".git", "a/b/"]
    expected = ["a.hs", "b.hs"]

--------------------------------------------------------------------------------
-- | stylish-haskell -e .git -e a/b/ a.hs b.hs .git a/b/c.hs
case12 :: Assertion
case12 = withTestDirTree $ do
  createDirectoryIfMissing True aDir
  createDirectoryIfMissing True gDir
  mapM_ (flip writeFile fileCont) input
  result <- findHaskellFiles True input toExclude
  result @?= expected
  where
    input    = ["a.hs", "b.hs", gDir </> c, aDir </> c]
    expected = ["a.hs", "b.hs"]
    toExclude = Just [aDir, gDir]
    c        = "c.hs"
    aDir     = "a" </> "b"
    gDir     = ".git"
    fileCont = ""