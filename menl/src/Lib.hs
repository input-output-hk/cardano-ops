{-# LANGUAGE OverloadedStrings #-}

module Lib where

import Turtle
import Data.Time
import Data.Time.Calendar

timestamp :: Pattern UTCTime
timestamp
  =  fmap parseNodeLogTime $ plus letter <> spaces <> plus digit <> spaces <> hhmmss

hhmmss :: Pattern Text
hhmmss =
  twoDigits <> text ":" <> twoDigits <> text ":" <> twoDigits
  where
    twoDigits = once digit <> once digit

headTimestamp :: Pattern UTCTime
headTimestamp = timestamp <* (spaces <> star dot)

txid :: Pattern Text
txid = do
  text "_unTxId = \\\""
  hash <- star alphaNum
  text "\\\""
  pure hash

txSubLine :: Pattern (UTCTime, Text)
txSubLine = do
  ldate <- timestamp
  text ", "
  txid <- plus alphaNum
  return (ldate, txid)

parseNodeLogTime :: Text -> UTCTime
parseNodeLogTime = parseTimeOrError True defaultTimeLocale timeFormat . repr
  where
    timeFormat = "\"%b %d %H:%M:%S\""

txVotingLine :: Pattern UTCTime
txVotingLine
  =   (text "Voting process started on: " *> timestamp)
  <|> (text "Voting process ended on: " *> timestamp)
