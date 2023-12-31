module RParser (Parser, parse, sat', sat, token, tok) where

import Data.Unique
import Data.Typeable
import System.IO.Unsafe
import Control.Applicative
import Data.Maybe

import qualified Parser as P

-- Newtype wrapper
newtype Parser tok a = MkP { unP :: P.Parser Unique tok a }

-- Eliminators

parses :: Parser tok a -> [tok] -> [a]
parses (MkP p) = P.parses p

parse :: Parser tok a -> [tok] -> Maybe a
parse p = listToMaybe . parses p

-- Non-recursive combinators

sat' :: Typeable a => (tok -> Maybe a) -> Parser tok a
sat' p = MkP (P.sat' p)

sat :: Typeable tok => (tok -> Bool) -> Parser tok tok
sat p = MkP (P.sat p)

token :: Typeable tok => Parser tok tok
token = MkP P.token

tok :: Eq tok => tok -> Parser tok tok
tok t = MkP (P.tok t)

-- | A thunk that knows its own identity
-- (a form of observable sharing without any heap manipulation/inspection!)
propriocept :: (Unique -> a) -> a
propriocept f = unsafePerformIO $ f <$> newUnique

withMemo :: P.Parser Unique tok a -> Parser tok a
withMemo p = propriocept $ \u -> MkP $ P.memoise u p

instance Functor (Parser tok) where
  fmap f p = withMemo (fmap f (unP p))

instance Applicative (Parser tok) where
  pure x = MkP (pure x)
  p1 <*> p2 = withMemo (unP p1 <*> unP p2)

instance Alternative (Parser tok) where
  empty = MkP empty
  p1 <|> p2 = withMemo (unP p1 <|> unP p2)

instance Monad (Parser tok) where
  return = pure
  p1 >>= f = withMemo $ unP p1 >>= unP . f

-- The large example from https://okmij.org/ftp/Haskell/LeftRecursion.hs

(>>>) :: Monoid a => Parser tok a -> Parser tok a -> Parser tok a
p1 >>> p2 = liftA2 (<>) p1 p2

char :: Char -> Parser Char String
char a = pure <$> tok a

s,a,b,c :: Parser Char String
s = s >>> a >>> c <|> c
a = b <|> char 'a' >>> c >>> char 'a'
b = id <$> b
c = char 'b' <|> c >>> a

-- ghci> parse s "babababa"
-- ["babababa"]
