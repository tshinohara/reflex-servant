{-# LANGUAGE TupleSections #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Reflex.Servant
  (
    -- * Deriving the endpoints
    reflexClient
  , HasReflexClient
  , ReflexClient
  , GenericClientM
  , Endpoint

    -- * Using the endpoints
  , endpoint
  , taggedEndpoint
  , ServantClientRunner

  ) where

import Reflex.Servant.Internal
import Servant.Client.Core
import Reflex
import Control.Monad.Identity
import Data.Coerce

type ServantClientRunner m = forall a. GenericClientM a -> m (Either ServantError a)

endpoint
  :: forall t m i o. PerformEvent t m
  => ServantClientRunner (Performable m)
  -> Endpoint i o
  -> Event t i
  -> m (Event t (Either ServantError o))
endpoint runner endpnt requestE = (coerceEvent :: Event t (Identity a) -> Event t a) <$>
  traverseEndpoint runner endpnt (coerceEvent requestE)

taggedEndpoint
  :: PerformEvent t m
  => ServantClientRunner (Performable m)
  -> Endpoint i o
  -> Event t (a, i)
  -> m (Event t (a, Either ServantError o))
taggedEndpoint = traverseEndpoint

-- | Sequential traversal of zero or more requests.
--
-- By choosing (a,) for @f@, you can tag your request with extra
-- information. Choosing 'Identity' is the same as 'endpoint'.
-- Choosing '[]' has the effect of performing possibly multiple
-- events in sequence.
--
-- The special case of zero elements is NOT handled differently, so
-- although the \'response\' will be quick, it seems likely that it
-- will occur in a subsequent frame.
traverseEndpoint
  :: ( PerformEvent t m
     , Traversable f
     )
  => ServantClientRunner (Performable m)
  -> Endpoint i o
  -> Event t (f i)
  -> m (Event t (f (Either ServantError o)))
traverseEndpoint runner endpnt requestE = do
  performEvent $ ffor requestE $ traverse (runner . runEndpoint endpnt)

-- TODO:
-- A variation of traverseEndpoint could make the response event immediate
-- when null. It seems that we need to map (const (error "")) though.
-- Don't forget to update the traverseEndpoint doc.

-- TODO:
-- Implement parallel traverseEndpoint. Probably needs an extra constraint
-- on Performable m
