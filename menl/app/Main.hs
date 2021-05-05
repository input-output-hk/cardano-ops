{-# LANGUAGE OverloadedStrings #-}

module Main where

import Lib
import Turtle
import Data.Text (isInfixOf)
import Data.Maybe (fromJust)
import Control.Arrow ((&&&))
import Data.Time
import Data.Time.Calendar
import qualified Control.Foldl as Fold
import Text.Pretty.Simple (pPrint)

main :: IO ()
main = do
  ts <- fold parseLog Fold.list
  pPrint ts
  where
    -- Parse the log file and extract the timestamp at which blocks were
    -- produced together with the transactions they contain
    parseLog :: Shell (UTCTime, [Text])
    parseLog = fmap ((extractTimestamp &&& extractTxIds) . lineToText)
             $ grep (has "TraceAdoptedBlock")
             $ input "out.txt"
      where
        extractTxIds :: Text -> [Text]
        extractTxIds = match (has txid)

        extractTimestamp :: Text -> UTCTime
        extractTimestamp x =
          parseTimeOrError True defaultTimeLocale timeFormat (repr textTimestamp)
          where
            timeFormat    = "\"%b %d %H:%M:%S\""
            textTimestamp = head $ match (begins headTimestamp) x
            -- we use head since the first element contains the longest match.
