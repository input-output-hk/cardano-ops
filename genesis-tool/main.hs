{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Data.Aeson
import qualified Data.ByteString as BS
import qualified Data.Map as Map
import           Data.Map (Map)
import           Data.HashMap.Strict (HashMap)
import qualified Data.HashMap.Strict as HashMap
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Base58 as B58
import qualified Data.ByteString.Base16 as B16
import           Data.Maybe
import           Data.Text.Encoding
import           GHC.Generics
import           System.Environment
import           Data.Hashable
import           Data.Text (Text)

data Input = Input
  { inputFunds :: [InputFund]
  } deriving (Show, Generic)

instance FromJSON Input where
  parseJSON = withObject "Input" $ \v -> Input <$> v .: "fund"

data InputFund = InputFund
  { inputFundAddress :: Base58Address
  , inputFundValue :: Integer
  } deriving (Show, Generic)

instance FromJSON InputFund where
  parseJSON = withObject "InputFund" $ \v -> InputFund <$> v .: "address" <*> v .: "value"

newtype Base58Address = Base58Address ByteString deriving (Show, Generic)
newtype HexAddress = HexAddress ByteString deriving (Show, Ord, Eq)

instance Hashable HexAddress where
  hashWithSalt a (HexAddress bs) = hashWithSalt a bs

instance FromJSON Base58Address where
  parseJSON = withText "Base58Address" $ \s -> (Base58Address . fromJust . (B58.decodeBase58 B58.bitcoinAlphabet) . encodeUtf8) <$> (pure s)

data Output = Output
  { initialFunds :: HashMap HexAddress Integer
  } deriving Show

encodeKey :: (HexAddress, Integer) -> (Text, Value)
encodeKey (HexAddress key, value) = (decodeUtf8 $ B16.encode key, toJSON value)

instance ToJSON Output where
  toJSON (Output funds) = Object $ HashMap.fromList $ map encodeKey $ HashMap.toList funds

main :: IO ()
main = do
  args <- getArgs
  let
    go :: [String] -> IO (Either String Input)
    go [path] = eitherDecodeFileStrict path
    convertFund :: InputFund -> (HexAddress, Integer)
    convertFund (InputFund (Base58Address addr) value) = (HexAddress $ B16.encode addr, value)
    go2 (Left err) = do
      print err
    go2 (Right (Input funds)) = do
      let
        output = Output $ HashMap.fromList $ map convertFund funds
      encodeFile "output.json" output
      print "done"
  result1 <- go args
  go2 result1
