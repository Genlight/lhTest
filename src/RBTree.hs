{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple" @-}
{-@ LIQUID "--bscope" @-}


-- Die test Funktion steigt nun immer in das rechte Kind ab. Dann bauen
-- wir den Baum wieder rekursiv zusammen wie in wavl-insert. Wenn wir
-- ein Blatt erreichen ändern wir die Farbe von schwarz auf rot, das hat
-- Kosten 1. Wenn die Farbe rot ist, machen wir nichts. Beim aufsteigen
-- checken wir immer, ob sich die Farbe des Teilbaums beim rekursiven
-- Aufruf geändert hat. Wenn sie sich geändert hat, machen wir das selbe
-- wie beim Blatt Fall. Wenn sie sich nicht geändert hat machen wir nichts.


module RBTree where 

import Prelude hiding (pure, (<*>), (>>=), (<$>))
import Language.Haskell.Liquid.RTick as RTick

data Col = R | B deriving (Eq, Show)

{-@ data Tree [ht] a = Nil | Tree { val :: a, 
                                    rd :: Col,
                                    ht1 :: {v:Nat | v >= 1 },
                                    left :: ChildT a ht1,
                                    right :: ChildT a ht1 } @-} 
data Tree a = Nil | Tree { val :: a, rd :: Col, ht1:: Int, left :: (Tree a), right :: (Tree a)} deriving Show


{-@ type ChildT a T = {v:Tree a | ht v + 1 <= T } @-}
{-@ type Nat = {v:Int | v >= 0} @-}

{-@ measure potT @-}
{-@ potT :: t:Tree a -> Nat / [ht t] @-}
potT :: Tree a -> Int
potT Nil = 0
potT t@(Tree _ c _ l r) 
    | c == B = 1 + potT l + potT r
    | otherwise = potT l + potT r

{-@ measure ht @-}
{-@ ht :: Tree a -> Nat @-}
ht              :: Tree a -> Int
ht Nil          = 0
ht (Tree x _ h l r) = h 

{-@ measure empty @-}
empty :: Tree a -> Bool
empty Nil = True
empty t@(Tree _ _ _ _ _) = False 

{-@ measure rk @-}
rk :: Tree a -> Col
rk Nil = R
rk t@(Tree _ c _ _ _) = c

{-@ test :: t:Tree a -> {v:Tree a | ht v == ht t }@-}
test :: Tree a -> Tree a
test Nil = Nil
test t@(Tree x c h l r) 
    | empty l && empty r && c == B = red t -- t is leaf, cost of 1 is incurred, and pot - 1
    | empty l && empty r && c == R = Tree x c h l r -- t is leaf, no cost 
    | otherwise = check (rk r) (Tree x c h l (test r)) -- do the checking which changes colours to red if a change happened in r

{-@ check :: Col -> t:Tree a -> {v:Tree a | ht t == ht v} @-}
check :: Col -> Tree a -> Tree a
check c Nil = Nil
check c t@(Tree a b h l r) 
    | rk r == c = t -- no change
    | rk r /= c && b == R = t -- this is the "rebalancing" step we are looking for, set cost to 2, no pot change
    | otherwise = red t  -- change B to R, incur cost of 1 and pot - 1

 -- do the checking which changes colours to red if a change happened in r
{-@ testT :: t:Tree a -> v:Tick ({v':Tree a | ht t == ht v'}) @-}
testT :: Tree a -> Tick (Tree a)
testT Nil = RTick.return Nil
testT t@(Tree x c h l r)
    | empty l && empty r && c == B = RTick.wait (red t) -- t is leaf, cost of 1 is incurred, and pot - 1
    | empty l && empty r && c == R = RTick.return (Tree x c h l r) -- t is leaf, no cost 
    | otherwise = checkT (rk r) ((Tree) <$> (pure x) <*> (pure c) <*> (pure h) <*> (pure l) <*> (testT r))

{-@ checkT :: Col -> t:Tick({t':Tree a | not empty t'}) -> {v:Tick (v':Tree a) | potT (tval v) + tcost v <= potT (tval t) + tcost t + 2 } @-}
checkT :: Col -> Tick(Tree a) -> Tick (Tree a)
checkT c t 
    | rk (right (tval t)) == c = t 
    | rk (right ( tval t)) /= c && rk (tval t) == R = RTick.step 2 t 
    | rk (right (tval t)) /= c && rk (tval t) == B = RTick.wmap red t

{-@ red :: {t:Tree a | not empty t && rk t == B} -> {v:Tree a | rk v == R && potT t == potT v + 1 && ht t == ht v } @-}
red :: Tree a -> Tree a
red t@(Tree a _ h l r) = Tree a R h l r

-- copied from my implementation in RTick, s. commit 
{-@ (<$>) :: f:(a -> b) -> t1:Tick a
                    -> { t:Tick b | Tick (tcost t1) (f (tval t1)) == t }
@-}
infixl 4 <$>
(<$>) :: (a -> b) -> Tick a -> Tick b
(<$>) = RTick.fmap