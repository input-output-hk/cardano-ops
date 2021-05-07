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
import qualified Data.Map.Strict as Map
import Data.Tuple (swap)

main :: IO ()
main = do
  -- Fetch the start and end of the voting period
  [s, e] <- fold parseVotingTimeLog Fold.list
  -- Fetch the submitted utxo transactions and their timestamps
  ts <- fold parseTxSubmissionLog Fold.list
  let txsSubmissionTime = Map.fromList
                        $ fmap swap ts
      txsSubmissionTimeBefore = Map.filter (<s) txsSubmissionTime
      txsSubmissionTimeDuring = Map.filter (\t -> s <= t && t <= e) txsSubmissionTime
  -- pPrint txsSubmissionTime
  pPrint $ "Total submitted UTxO transactions: "
         <> show (Map.size txsSubmissionTime)
  pPrint $ "Submitted UTxO transactions before the voting period: "
         <> show (Map.size txsSubmissionTimeBefore)
  pPrint $ "Submitted UTxO transactions during the voting period: "
         <> show (Map.size txsSubmissionTimeDuring)
  -- Fetch the block timestamps and transaction id's contained in them.
  bs <- fold parseNodeLog Fold.list
  -- Convert @bs ::[(UTCTime, [Text])]@ into a list of type @[(Text, UTCTime)]@
  -- so that we can construct a map from hashes (transaction id's) to the time
  -- they were added to a block.
  let txsInclusionTime = Map.fromList
                       $ concat
                       $ fmap (\(time, txs) -> zip txs (repeat time)) bs
  --  pPrint txsInclusionTime
  pPrint $ "Total transactions in the chain: "
         <> show (Map.size txsInclusionTime)
  -- Get the number of transactions before voting by counting the included
  -- transactions before the start of the voting period (@s@).
  let utxoTxsInclusionTime = txsInclusionTime `Map.intersection` txsSubmissionTime
      utxoTxsInclusionTimeBefore = Map.filter (<s) utxoTxsInclusionTime
      utxoTxsInclusionTimeDuring = Map.filter (\t -> s <= t && t <= e) utxoTxsInclusionTime
  pPrint $ "Transaction count before the voting period: "
         <> show (Map.size utxoTxsInclusionTimeBefore)
  pPrint $ "Transaction count during the voting period: "
         <> show (Map.size utxoTxsInclusionTimeDuring)
  -- Calculate the transaction latency
  let utxoLatenciesBefore =
        Map.intersectionWith diffUTCTime utxoTxsInclusionTimeBefore txsSubmissionTimeBefore
      utxoLatenciesDuring =
        Map.intersectionWith diffUTCTime utxoTxsInclusionTimeDuring txsSubmissionTimeDuring
  pPrint $ "Average transaction latency time before the voting period: "
         <> show (Fold.fold Fold.mean (Map.elems utxoLatenciesBefore))
  pPrint $ "Average transaction latency time during the voting period: "
         <> show (Fold.fold Fold.mean (Map.elems utxoLatenciesDuring))
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
