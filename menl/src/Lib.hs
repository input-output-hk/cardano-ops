{-# LANGUAGE OverloadedStrings #-}

module Lib where

import Turtle
import Data.Time
import Data.Time.Calendar

timestamp :: Pattern Text
timestamp
  =  plus letter <> spaces <> plus digit <> spaces
  <> plus digit <> text ":" <> plus digit <> text ":" <> plus digit

headTimestamp :: Pattern Text
headTimestamp = timestamp <* (spaces <> star dot)

txid :: Pattern Text
txid = do
  text "_unTxId = \\\""
  hash <- star alphaNum
  text "\\\""
  pure hash
