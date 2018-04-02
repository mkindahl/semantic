{-# LANGUAGE GADTs, RankNTypes, UndecidableInstances #-}
module Data.Abstract.Origin where

import qualified Data.Abstract.Module as M
import qualified Data.Abstract.Package as P
import Prologue

data Origin term ty where
  Unknown ::                                    Origin term any
  Package ::                   P.PackageInfo -> Origin term 'P
  Module  :: Origin term 'P -> M.ModuleInfo  -> Origin term 'M
  Term    :: Origin term 'M -> Base term ()  -> Origin term 'T

packageOrigin :: P.Package term -> SomeOrigin term
packageOrigin = SomeOrigin . Package . P.packageInfo

moduleOrigin :: M.Module term -> SomeOrigin term
moduleOrigin = SomeOrigin . Module Unknown . M.moduleInfo

termOrigin :: Recursive term => term -> SomeOrigin term
termOrigin = SomeOrigin . Term Unknown . (() <$) . project

originModule :: Origin term ty -> Maybe M.ModuleInfo
originModule (Term o _)   = originModule o
originModule (Module _ m) = Just m
originModule _            = Nothing

originPackage :: Origin term ty -> Maybe P.PackageInfo
originPackage (Term o _)   = originPackage o
originPackage (Module o _) = originPackage o
originPackage (Package p)  = Just p
originPackage _            = Nothing

deriving instance Eq (Base term ()) => Eq (Origin term ty)
deriving instance Show (Base term ()) => Show (Origin term ty)

eqOrigins :: Eq (Base term ()) => Origin term ty1 -> Origin term ty2 -> Bool
eqOrigins Unknown        Unknown        = True
eqOrigins (Package p1)   (Package p2)   = p1 == p2
eqOrigins (Module p1 m1) (Module p2 m2) = p1 == p2 && m1 == m2
eqOrigins (Term m1 t1)   (Term m2 t2)   = m1 == m2 && t1 == t2
eqOrigins _              _              = False

compareOrigins :: Ord (Base term ()) => Origin term ty1 -> Origin term ty2 -> Ordering
compareOrigins Unknown        Unknown        = EQ
compareOrigins Unknown        _              = LT
compareOrigins _              Unknown        = GT
compareOrigins (Package p1)   (Package p2)   = compare p1 p2
compareOrigins (Package _)    _              = LT
compareOrigins _              (Package _)    = GT
compareOrigins (Module p1 m1) (Module p2 m2) = compare p1 p2 <> compare m1 m2
compareOrigins (Module _ _)   _              = LT
compareOrigins _              (Module _ _)   = GT
compareOrigins (Term m1 t1)   (Term m2 t2)   = compare m1 m2 <> compare t1 t2

instance Ord (Base term ()) => Ord (Origin term ty) where
  compare = compareOrigins

data OriginType = P | M | T
  deriving (Eq, Ord, Show)

data SomeOrigin term where
  SomeOrigin :: Origin term ty -> SomeOrigin term

withSomeOrigin :: (forall ty . Origin term ty -> b) -> SomeOrigin term -> b
withSomeOrigin with (SomeOrigin o) = with o

instance Eq (Base term ()) => Eq (SomeOrigin term) where
  SomeOrigin o1 == SomeOrigin o2 = eqOrigins o1 o2

instance Ord (Base term ()) => Ord (SomeOrigin term) where
  compare (SomeOrigin o1) (SomeOrigin o2) = compareOrigins o1 o2

deriving instance Show (Base term ()) => Show (SomeOrigin term)


merge :: Origin term ty1 -> Origin term ty2 -> SomeOrigin term
merge a                     Unknown                     = SomeOrigin a
merge (Package p)           (Module Unknown m)          = SomeOrigin (Module (Package p) m)
merge (Module p _)          (Module Unknown m)          = SomeOrigin (Module p m)
merge (Term (Module p _) _) (Module Unknown m)          = SomeOrigin (Module p m)
merge (Term (Module p _) _) (Term (Module Unknown m) t) = SomeOrigin (Term (Module p m) t)
merge (Module p m)          (Term Unknown t)            = SomeOrigin (Term (Module p m) t)
merge (Term m _)            (Term Unknown t)            = SomeOrigin (Term m t)
merge _                     b                           = SomeOrigin b

instance Semigroup (SomeOrigin term) where
  SomeOrigin a <> SomeOrigin b = merge a b

instance Monoid (SomeOrigin term) where
  mempty = SomeOrigin Unknown
  mappend = (<>)
