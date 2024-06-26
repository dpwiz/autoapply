{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# OPTIONS_GHC -Wno-missing-signatures #-}
{-# OPTIONS_GHC -Wno-missing-methods #-}

module Types where

import           AutoApply
import           Control.Monad.IO.Class
import           Data.Kind

----------------------------------------------------------------
-- Values to test with
----------------------------------------------------------------

newtype Resource a = Resource a

myBracket
  :: MyConstraint m
  => MyMonadT m a
  -> (a -> MyMonadT m c)
  -> (a -> MyMonadT m b)
  -> MyMonadT m b
myBracket = undefined

class MonadResource (m :: Type -> Type) where
data ReleaseKey
myAllocate :: MonadResource m => IO a -> (a -> IO ()) -> m (ReleaseKey, a)
myAllocate = undefined

data Baz
data Qux

class Monad m => MyConstraint (m :: Type -> Type) where

newtype MyMonadT a b = MyMonadT (a b)
  deriving newtype (Functor, Applicative, Monad)

instance MonadIO m => MonadIO (MyMonadT m) where
  liftIO = undefined

getBazSem :: MyConstraint m => MyMonadT m Baz
getBazSem = undefined

getQux :: m Qux
getQux = undefined

getQuxIO :: IO Qux
getQuxIO = undefined

aQux :: Qux
aQux = undefined

-- $setup
-- >>> :set -XTemplateHaskell
-- >>> import Control.Exception

----------------------------------------------------------------
-- Tests
----------------------------------------------------------------

-- basic test
autoapplyDecs (<> "'") [] [] ['id]

-- | Simple monadic binding
--
-- >>> x = $(autoapply [] ['getQuxIO] 'test0)
-- >>> :t x
-- x :: Baz -> IO ()
test0 :: Baz -> Qux -> m ()
test0 = undefined

-- | Simple polymorphic monadic binding
--
-- >>> x = $(autoapply [] ['getQux] 'test0')
-- >>> :t x
-- x :: Monad m => Baz -> m ()
test0' :: Baz -> Qux -> m ()
test0' = undefined

-- | Two monadic bindings
--
-- >>> x = $(autoapply [] ['getBazSem, 'getQux] 'test1)
-- >>> :t x
-- x :: MyConstraint m => MyMonadT m ()
test1 :: Baz -> Qux -> m ()
test1 = undefined

-- | 'aQux' is substituted and 'Baz' is left as an argument
--
-- >>> x = $(autoapply [] ['aQux] 'test2)
-- >>> :t x
-- x :: Baz -> m ()
test2 :: Baz -> Qux -> m ()
test2 = undefined

-- | 'id' gets substituted at @(a -> a)@
--
-- >>> $(autoapply [] ['id] 'test3)
-- ()
test3 :: (a -> a) -> ()
test3 = const ()

-- | 'id' gets substituted at @(a -> b)@
--
-- >>> $(autoapply [] ['id] 'test4)
-- ()
test4 :: (a -> b) -> ()
test4 = const ()

-- | @aQux :: Qux@ gets substituted at @a@

-- >>> $(autoapply [] ['aQux] 'test5)
-- ()
test5 :: a -> ()
test5 = const ()

-- | 'id' does not get substituted at @(forall a b. a -> b)@
--
-- >>> x = $(autoapply [] ['id] 'test6)
-- >>> :t x
-- x :: (forall a b. a -> b) -> ()
--
-- 'undefined' does
-- >>> x = $(autoapply [] ['undefined] 'test6)
-- >>> :t x
-- x :: ()
test6 :: (forall a b. a -> b) -> ()
test6 = \x -> const () x
autoapplyDecs (<> "'") [] ['id] ['test6]
test6' :: (forall a b. a -> b) -> ()

-- | @aQux :: Qux@ does not get substituted at @forall a. a@
--
-- >>> x = $(autoapply [] ['aQux] 'test7)
-- >>> :t x
-- x :: (forall a. a) -> ()
test7 :: (forall a. a) -> ()
test7 = \x -> const () x

-- | 'id' is instantiated twice at different types
-- >>> $(autoapply [] ['id] 'test8)
-- ()
test8 :: (Baz -> Baz) -> (Qux -> Qux) -> ()
test8 = const (const ())

-- | The return type changes
--
-- >>> x = $(autoapply [] ['reverse] 'test9)
-- >>> :t x
-- x :: [a] -> [a]
--
-- Applied in argument order (This example is in the reader monad)
--
-- >>> x = $(autoapply [] ['reverse] 'test9')
-- >>> :t x
-- x :: ([a] -> [a] -> b) -> [a] -> b
test9 :: ([a] -> b) -> [a] -> b
test9 = undefined

test9' :: [a] -> ([a] -> b) -> b
test9' = undefined

-- | Two monadic bindings with types incompatible with one another
--
-- >>> x = $(autoapply [] ['getBazSem, 'getQuxIO] 'test10)
-- >>> :t x
-- x :: MyConstraint m => Qux -> MyMonadT m ()
--
-- Responds to the order of types in the applying function, not the order types
-- of values to be passed.
-- >>> x = $(autoapply [] ['getQuxIO, 'getBazSem] 'test10)
-- >>> :t x
-- x :: MyConstraint m => Qux -> MyMonadT m ()
test10 :: Baz -> Qux -> m ()
test10 = undefined

-- | Monadic binding with incompatible type
--
-- >>> x = $(autoapply [] ['getBazSem, 'getQuxIO] 'test11)
-- >>> :t x
-- x :: Baz -> IO ()
test11 :: Baz -> Qux -> IO ()
test11 = undefined

-- | Several instantiations of the same function
--
-- >>> x = $(autoapply [] ['bracket, 'getBazSem, 'aQux] 'test12)
-- >>> :t x
-- x :: Baz -> (a -> IO c) -> IO c
--
-- >>> x = $(autoapply [] ['myBracket, 'aQux] 'test12)
-- >>> :t x
-- x :: MyConstraint m => Baz -> (a -> MyMonadT m b) -> MyMonadT m b
--
-- >>> x = $(autoapply [] ['myAllocate, 'aQux] 'test12)
-- >>> :t x
-- x :: MonadResource m => Baz -> m (ReleaseKey, a)
test12 :: (m a -> (a -> m b) -> c) -> Baz -> Qux -> c
test12 = undefined

-- | Can change the type of the output monad
--
-- >>> x = $(autoapply [] ['getQuxIO] 'test13)
-- >>> :t x
-- x :: IO Baz
test13 :: Monad m => Qux -> m Baz
test13 = undefined

-- | Invents a monad
--
-- >>> x = $(autoapply [] ['getQuxIO] 'test14)
-- >>> :t x
-- x :: IO b
test14 :: Qux -> b
test14 = undefined

-- | Unifies variable with monad
--
-- >>> x = $(autoapply [] ['getQuxIO] 'test15)
-- >>> :t x
-- x :: IO b
test15 :: Qux -> a b
test15 = undefined

-- | Invents monad return var
--
-- >>> x = $(autoapply [] ['ioUnit] 'test16)
-- >>> :t x
-- x :: IO ()
test16 :: (a -> b) -> b
test16 = undefined
ioUnit :: a -> IO ()
ioUnit = const (pure ())

-- | Uses invented var, i.e. if we unify @b@ with @IO ()@ then we can try to
-- use monad parameters.
--
-- >>> x = $(autoapply [] ['ioUnit, 'getQuxIO] 'test17)
-- >>> :t x
-- x :: IO ()
test17 :: (a -> b) -> Qux -> b
test17 = undefined

-- | Unifies @a -> b@ with 'pure'
--
-- >>> x = $(autoapply [] ['pure] 'test18)
-- >>> :t x
-- x :: Applicative f => f a
test18 :: (a -> b) -> b
test18 = undefined

-- | Uses invented with polymorphic return type, i.e. if we unify @b@ with @m
-- a@ then we can try to use monad parameters.
--
-- >>> x = $(autoapply [] ['pure, 'getQuxIO] 'test19)
-- >>> :t x
-- x :: IO b
test19 :: (a -> b) -> Qux -> b
test19 = undefined

-- | Changes type of argument to match return type
--
-- >>> x = $(autoapply [] ['getQuxIO] 'test20)
-- >>> :t x
-- x :: (a -> IO b) -> IO b
test20 :: (a -> b) -> Qux -> b
test20 = undefined

-- |
--
-- >>> x = $(autoapply [] ['exitFailure] 'liftIO)
-- >>> :t x
-- x :: MonadIO m => m a
exitFailure :: IO a
exitFailure = undefined

-- | Respects basic constraints
--
-- >>> x = $(autoapply [] ['id] 'test21)
-- >>> :t x
-- x :: Num a => a -> (a, Bool)
--
-- >>> n = 1 :: Int
-- >>> x = $(autoapply [] ['n] 'test21)
-- >>> :t x
-- x :: (Int, Bool)
test21 :: Num a => a -> (a, Bool)
test21 = undefined

-- | Doesn't pass 'reverse' to '+'
--
-- >>> x = $(autoapply [] ['reverse] '(+))
-- >>> :t x
-- x :: Num a => a -> a -> a

-- | Respects basic constraints 2
--
-- >>> x = $(autoapply [] ['getBazSem] 'test22)
-- >>> :t x
-- x :: (MyConstraint m, MyClass a, MonadIO m) => a -> MyMonadT m ()
class MyClass (a :: Type) where
instance MyClass Int where
test22 :: (MyClass a, MonadIO m) => Baz -> a -> m ()
test22 = undefined

-- | Fails with uninhabited classes
--
-- >>> x = $(autoapply [] [] 'test23)
-- <BLANKLINE>
-- <interactive>:...: error:...
--     • "Impossible" Finding argument provenances failed (unless the function context containts a class with no instances)
--     • In the untyped splice: $(autoapply [] [] 'test23)
class MyClassWithNoInstances (a :: Type) where
test23 :: (MyClassWithNoInstances a) => a -> b
test23 = undefined

-- | Respects constraints with subsumption
--
-- >>> x = $(autoapply [] ['getInt] 'test24)
-- >>> :t x
-- x :: ()
--
-- >>> x = $(autoapply ['getInt] [] 'test24)
-- >>> :t x
-- x :: MyClass2 a => a -> ()
class MyClass2 (a :: Type) where
instance MyClass2 Int where
getInt :: Int
getInt = 0
test24 :: MyClass2 a => Int -> a -> ()
test24 = undefined

-- | Works with closed type families
--
-- >>> x = $(autoapply [] ['getInt] 'test25)
-- >>> :t x
-- x :: ()
type family ClosedFam (a :: Type) :: Constraint where
  ClosedFam Int = ()
test25 :: ClosedFam a => a -> ()
test25 = undefined

-- | Works with open type families
--
-- >>> x = $(autoapply [] ['getInt] 'test26)
-- >>> :t x
-- x :: ()
type family OpenFam (a :: Type) :: Constraint
-- type instance OpenFam Int = ()
type instance OpenFam a = ()

test26 :: OpenFam a => a -> ()
test26 = undefined

----------------------------------------------------------------
-- Examples from readme
----------------------------------------------------------------

class Member a (r :: [Type]) where
instance Member a b where
data Sem (r :: [Type]) a
instance Functor (Sem r)
instance Applicative (Sem r)
instance Monad (Sem r)
instance MonadIO (Sem r)
data Input a
input :: Member (Input a) r => Sem r a
input = undefined

data Instance; data ExtraOpenInfo; data Foo; data Bar; data Handle
openHandle :: MonadIO m => Instance -> Maybe ExtraOpenInfo -> m Handle
openHandle = undefined
closeHandle :: MonadIO m => Instance -> Handle -> m ()
closeHandle = undefined
useHandle :: MonadIO m => Instance -> Handle -> Foo -> m Bar
useHandle = undefined

myExtraOpenInfo :: Maybe ExtraOpenInfo
myExtraOpenInfo = Nothing
getInstance :: Member (Input Instance) r => Sem r Instance
getInstance = input
getFoo :: MyConstraint m => m Foo
getFoo = undefined

autoapplyDecs
  (<> "'")
  ['myExtraOpenInfo, 'getInstance, 'getFoo]
  []
  ['openHandle, 'closeHandle, 'useHandle]

openHandle'
  :: (Member (Input Instance) r, MonadIO (Sem r)) => Sem r Handle
closeHandle'
  :: (Member (Input Instance) r, MonadIO (Sem r)) => Handle -> Sem r ()
useHandle'
  :: (Member (Input Instance) r, MyConstraint (Sem r), MonadIO (Sem r))
  => Handle -> Sem r Bar
