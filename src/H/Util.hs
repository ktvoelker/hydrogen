
module H.Util where

import qualified Data.Map as M
import qualified Data.Text as T

import H.Import

data ExitCode = ExitSuccess | ExitFailure deriving (Eq, Ord, Enum, Bounded, Read, Show)

instance Monoid ExitCode where
  mempty = ExitSuccess
  mappend ExitSuccess ExitSuccess = ExitSuccess
  mappend _ _ = ExitFailure

todo :: a
todo = error "Not implemented"

impossible :: String -> a
impossible = error . ("Impossible: " ++)

readMaybe :: (Read a) => String -> Maybe a
readMaybe = fmap fst . listToMaybe . reads

whenJust :: (Monad m) => Maybe a -> (a -> m ()) -> m ()
whenJust x f = maybe (return ()) f x

onFst :: (a -> c) -> (a, b) -> (c, b)
onFst f (a, b) = (f a, b)

onSnd :: (b -> c) -> (a, b) -> (a, c)
onSnd f (a, b) = (a, f b)

onFstF :: (Functor f) => (a -> f c) -> (a, b) -> f (c, b)
onFstF f (a, b) = (, b) <$> f a

onSndF :: (Functor f) => (b -> f c) -> (a, b) -> f (a, c)
onSndF f (a, b) = (a, ) <$> f b

lift2 :: (MonadTrans t, MonadTrans u, Monad m, Monad (u m)) => m a -> t (u m) a
lift2 = lift . lift

lift3
  :: ( MonadTrans t
     , MonadTrans u
     , MonadTrans v
     , Monad m
     , Monad (u m)
     , Monad (t (u m))
     )
  => m a
  -> v (t (u m)) a
lift3 = lift . lift . lift

lift4
  :: ( MonadTrans t
     , MonadTrans u
     , MonadTrans v
     , MonadTrans w
     , Monad m
     , Monad (u m)
     , Monad (t (u m))
     , Monad (v (t (u m)))
     )
  => m a
  -> w (v (t (u m))) a
lift4 = lift . lift . lift . lift

modifyM :: (MonadState s m) => (s -> m s) -> m ()
modifyM = (>>= put) . (get >>=) 

(%>>=) :: (MonadState a m) => Lens a b -> (b -> m b) -> m b
(%>>=) lens f = access lens >>= f >>= (lens ~=)

infixr 4 %>>=

newtype AppendList a = AppendList ([a] -> [a])

emptyAppendList :: AppendList a
emptyAppendList = AppendList id

appendElem :: a -> AppendList a -> AppendList a
appendElem x (AppendList f) = AppendList $ f . (x :)

appendList :: [a] -> AppendList a -> AppendList a
appendList xs (AppendList f) = AppendList $ f . (xs ++)

realizeList :: AppendList a -> [a]
realizeList (AppendList f) = f []

-- | Get a list of all possible splits of the input list, where the element at each
-- | position is treated as a pivot (not included in either side of the split).
splits :: [a] -> [([a], [a])]
splits = f emptyAppendList emptyAppendList
  where
    f acc _ [] = realizeList acc
    f acc h (t : ts) = f acc' h' ts
      where
        h' = appendElem t h
        acc' = appendElem (realizeList h, ts) acc

minimumByM :: (Monad m) => (a -> a -> m Ordering) -> [a] -> m a
minimumByM _ [] = error "minimumByM: Empty list"
minimumByM c (x : xs) = f x c xs
  where
    f acc _ [] = return acc
    f acc c (x : xs) = do
      o <- c x acc
      case o of
        LT -> f x c xs
        _ -> f acc c xs

data Proxy a = Proxy

asProxied :: a -> Proxy a -> a
asProxied = const

infix 8 `asProxied`

eitherAlt :: (Alternative f) => f a -> f b -> f (Either a b)
eitherAlt la ra = (Left <$> la) <|> (Right <$> ra)

infixl 3 `eitherAlt`

showText :: (Show a) => a -> T.Text
showText = T.pack . show
 
type FileMap a = Map FilePath a

sequenceWhileJust :: (Monad m) => [m (Maybe a)] -> m [a]
sequenceWhileJust [] = return []
sequenceWhileJust (m : ms) =
  m >>= maybe (return []) (\x -> liftM (x :) $ sequenceWhileJust ms)

isLeft :: Either a b -> Bool
isLeft (Left _)  = True
isLeft (Right _) = False

isRight :: Either a b -> Bool
isRight (Right _) = True
isRight (Left _)  = False

headView :: [a] -> Maybe (a, [a])
headView [] = Nothing
headView (x : xs) = Just (x, xs)

fst3 :: (a, b, c) -> a
fst3 (x, _, _) = x

unionWithM :: (Ord k, Monad m) => (a -> a -> m a) -> Map k a -> Map k a -> m (Map k a)
unionWithM f a b =
  liftM M.fromList
    . sequence
    . map (\(k, v) -> liftM (k,) v)
    . M.toList
    $ M.unionWith f' (M.map return a) (M.map return b)
  where
    f' mx my = mx >>= \x -> my >>= \y -> f x y

