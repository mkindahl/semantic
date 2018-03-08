{-# LANGUAGE DefaultSignatures, UndecidableInstances, GeneralizedNewtypeDeriving #-}
module Data.Abstract.FreeVariables where

import Data.ByteString (intercalate)
-- import qualified Data.ByteString.Char8 as BC
import Data.Term
import Prologue
import qualified Data.List.NonEmpty as NonEmpty

-- | The type of variable names.
newtype Name = Name { unName :: NonEmpty ByteString }
  deriving (Eq, Ord, Show, Semigroup)

-- instance Show Name where
--   showsPrec _ n = showChar '\"' . showString (BC.unpack (friendlyName n)) . showChar '\"'

name :: ByteString -> Name
name x = Name $ x :| []

qualifiedName :: [ByteString] -> Name
qualifiedName = Name . NonEmpty.fromList

friendlyName :: Name -> ByteString
friendlyName (Name xs) = intercalate "." (NonEmpty.toList xs)


-- | Types which can contain unbound variables.
class FreeVariables term where
  -- | The set of free variables in the given value.
  freeVariables :: term -> Set Name


-- | A lifting of 'FreeVariables' to type constructors of kind @* -> *@.
--
--   'Foldable' types requiring no additional semantics to the set of free variables (e.g. types which do not bind any variables) can use (and even derive, with @-XDeriveAnyClass@) the default implementation.
class FreeVariables1 syntax where
  -- | Lift a function mapping each element to its set of free variables through a containing structure, collecting the results into a single set.
  liftFreeVariables :: (a -> Set Name) -> syntax a -> Set Name
  default liftFreeVariables :: (Foldable syntax) => (a -> Set Name) -> syntax a -> Set Name
  liftFreeVariables = foldMap

-- | Lift the 'freeVariables' method through a containing structure.
freeVariables1 :: (FreeVariables1 t, FreeVariables a) => t a -> Set Name
freeVariables1 = liftFreeVariables freeVariables

freeVariable :: FreeVariables term => term -> Name
freeVariable term = let [n] = toList (freeVariables term) in n

-- TODO: Need a dedicated concept of qualified names outside of freevariables (a
-- Set) b/c you can have something like `a.a.b.a`
-- qualifiedName :: FreeVariables term => term -> Name
-- qualifiedName term = let names = toList (freeVariables term) in B.intercalate "." names

instance (FreeVariables1 syntax, Functor syntax) => FreeVariables (Term syntax ann) where
  freeVariables = cata (liftFreeVariables id)

instance (FreeVariables1 syntax) => FreeVariables1 (TermF syntax ann) where
  liftFreeVariables f (In _ s) = liftFreeVariables f s

instance (Apply FreeVariables1 fs) => FreeVariables1 (Union fs) where
  liftFreeVariables f = apply (Proxy :: Proxy FreeVariables1) (liftFreeVariables f)

instance FreeVariables1 []
