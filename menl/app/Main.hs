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
  -- Fetch the block timestamps and transaction id's contained in them.
  bs <- fold parseNodeLog Fold.list
  pPrint bs
  -- Fetch the submitted utxo transactions and their timestamps
  ts <- fold parseTxSubmissionLog Fold.list
  pPrint ts
  -- Fetch the start and end of the voting period
  [s, e] <- fold parseVotingTimeLog Fold.list
  print (s, e)
  -- TODO: NEXT: now that we've parsed the information from the logs process it!
  where
    -- Parse the log file and extract the timestamp at which blocks were
    -- produced together with the transactions they contain
    parseNodeLog :: Shell (UTCTime, [Text])
    parseNodeLog = fmap ((extractTimestamp &&& extractTxIds) . lineToText)
                 $ grep (has "TraceAdoptedBlock")
                 $ input "../bft-node.log"
      where
        extractTxIds :: Text -> [Text]
        extractTxIds = match (has txid)

        extractTimestamp :: Text -> UTCTime
        extractTimestamp = head . match headTimestamp
                           -- we use head since the first element contains the longest match.
    parseTxSubmissionLog :: Shell (UTCTime, Text)
    parseTxSubmissionLog =
      fmap (head . match txSubLine . lineToText) $ input "../bft-nodes-tx-submission.log"

    parseVotingTimeLog :: Shell UTCTime
    parseVotingTimeLog =
      fmap (head . match txVotingLine . lineToText) $ input "../voting-timing.log"
