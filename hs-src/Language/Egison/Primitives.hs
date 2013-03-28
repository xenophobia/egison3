{-# Language FlexibleContexts #-}
module Language.Egison.Primitives (primitiveEnv) where

import Control.Arrow
import Control.Applicative
import Control.Monad.Error

import Data.IORef

import System.IO

import Language.Egison.Types
import Language.Egison.Core

primitiveEnv :: IO Env
primitiveEnv = do
  let ops = map (second PrimitiveFunc) (primitives ++ ioPrimitives) ++
            map (second IOFunc) assertions
  bindings <- forM ops $ \(name, op) -> do
    ref <- newIORef . WHNF $ Value op
    return ((name, []), ref)
  return $ extendEnv nullEnv bindings

{-# INLINE noArg #-}
noArg :: (MonadError EgisonError m) =>
         m EgisonValue ->
         [WHNFData] -> m EgisonValue
noArg f = \vals -> case vals of 
                     [] -> f
                     _ -> throwError $ ArgumentsNum 0 vals

{-# INLINE oneArg #-}
oneArg :: (MonadError EgisonError m) =>
          (WHNFData -> m EgisonValue) ->
          [WHNFData] -> m EgisonValue
oneArg f = \vals -> case vals of 
                      [val] -> f val
                      _ -> throwError $ ArgumentsNum 1 vals

{-# INLINE twoArgs #-}
twoArgs :: (MonadError EgisonError m) =>
           (WHNFData -> WHNFData -> m EgisonValue) ->
           [WHNFData] -> m EgisonValue
twoArgs f = \vals -> case vals of 
                       [val, val'] -> f val val'
                       _ -> throwError $ ArgumentsNum 2 vals

--
-- Primitives
--

primitives :: [(String, PrimitiveFunc)]
primitives = [ ("+", integerBinaryOp (+)) 
             , ("-", integerBinaryOp (-))
             , ("*", integerBinaryOp (*))
             , ("modulo",    integerBinaryOp mod)
             , ("qutient",   integerBinaryOp quot)
             , ("remainder", integerBinaryOp rem)
             , ("eq-n?",  integerBinaryPred (==))
             , ("lt-n?",  integerBinaryPred (<))
             , ("lte-n?", integerBinaryPred (<=))
             , ("gt-n?",  integerBinaryPred (>))
             , ("gte-n?", integerBinaryPred (>=))
             , ("+f", floatBinaryOp (+))
             , ("-f", floatBinaryOp (-))
             , ("*f", floatBinaryOp (*))
             , ("/f", floatBinaryOp (/))
             , ("eq-f?",  floatBinaryPred (==))
             , ("lt-f?",  floatBinaryPred (<))
             , ("lte-f?", floatBinaryPred (<=))
             , ("gt-f?",  floatBinaryPred (>))
             , ("gte-f?", floatBinaryPred (>=))
             , ("sqrt", floatUnaryOp sqrt)
             , ("exp", floatUnaryOp exp)
             , ("log", floatUnaryOp log)
             , ("sin", floatUnaryOp sin)
             , ("cos", floatUnaryOp cos)
             , ("tan", floatUnaryOp tan)
             , ("asin", floatUnaryOp asin)
             , ("acos", floatUnaryOp acos)
             , ("atan", floatUnaryOp atan)
             , ("sinh", floatUnaryOp sinh)
             , ("cosh", floatUnaryOp cosh)
             , ("tanh", floatUnaryOp tanh)
             , ("asinh", floatUnaryOp asinh)
             , ("acosh", floatUnaryOp acosh)
             , ("atanh", floatUnaryOp atanh)
             , ("round",    floatToIntegerOp round)
             , ("floor",    floatToIntegerOp floor)
             , ("ceiling",  floatToIntegerOp ceiling)
             , ("truncate", floatToIntegerOp truncate)
             , ("eq?",  eq)
             , ("lt?",  lt)
             , ("lte?", lte)
             , ("gt?",  gt)
             , ("gte?", gte) ]

integerBinaryOp :: (Integer -> Integer -> Integer) -> PrimitiveFunc
integerBinaryOp op = twoArgs $ \val val' ->
  (Integer .) . op <$> fromIntegerValue val
                   <*> fromIntegerValue val'

integerBinaryPred :: (Integer -> Integer -> Bool) -> PrimitiveFunc
integerBinaryPred pred = twoArgs $ \val val' ->
  (Bool .) . pred <$> fromIntegerValue val
                  <*> fromIntegerValue val'

floatUnaryOp :: (Double -> Double) -> PrimitiveFunc
floatUnaryOp op = oneArg $ \val ->
  Float . op <$> fromFloatValue val

floatBinaryOp :: (Double -> Double -> Double) -> PrimitiveFunc
floatBinaryOp op = twoArgs $ \val val' ->
  (Float .) . op <$> fromFloatValue val
                 <*> fromFloatValue val'

floatBinaryPred :: (Double -> Double -> Bool) -> PrimitiveFunc
floatBinaryPred pred = twoArgs $ \val val' ->
  (Bool .) . pred <$> fromFloatValue val
                  <*> fromFloatValue val'

floatToIntegerOp :: (Double -> Integer) -> PrimitiveFunc
floatToIntegerOp op = oneArg $ \val ->
  Integer . op <$> fromFloatValue val

eq :: PrimitiveFunc
eq = twoArgs $ \val val' ->
  (Bool .) . (==) <$> fromPrimitiveValue val
                  <*> fromPrimitiveValue val'

lt :: PrimitiveFunc
lt = twoArgs lt'
 where
  lt' (Value (Integer i)) (Value (Integer i')) = return $ Bool $ i < i
  lt' (Value (Integer i)) (Value (Float f)) = return $ Bool $ fromInteger i < f
  lt' (Value (Float f)) (Value (Integer i)) = return $ Bool $ f < fromInteger i
  lt' (Value (Float f)) (Value (Float f')) = return $ Bool $ f < f
  lt' (Value (Integer _)) val = throwError $ TypeMismatch "number" val
  lt' (Value (Float _)) val = throwError $ TypeMismatch "number" val
  lt' val _ = throwError $ TypeMismatch "number" val

lte :: PrimitiveFunc
lte = twoArgs lte'
 where
  lte' (Value (Integer i)) (Value (Integer i')) = return $ Bool $ i <= i
  lte' (Value (Integer i)) (Value (Float f)) = return $ Bool $ fromInteger i <= f
  lte' (Value (Float f)) (Value (Integer i)) = return $ Bool $ f <= fromInteger i
  lte' (Value (Float f)) (Value (Float f')) = return $ Bool $ f <= f
  lte' (Value (Integer _)) val = throwError $ TypeMismatch "number" val
  lte' (Value (Float _)) val = throwError $ TypeMismatch "number" val
  lte' val _ = throwError $ TypeMismatch "number" val

gt :: PrimitiveFunc
gt = twoArgs gt'
 where
  gt' (Value (Integer i)) (Value (Integer i')) = return $ Bool $ i > i
  gt' (Value (Integer i)) (Value (Float f)) = return $ Bool $ fromInteger i > f
  gt' (Value (Float f)) (Value (Integer i)) = return $ Bool $ f > fromInteger i
  gt' (Value (Float f)) (Value (Float f')) = return $ Bool $ f > f
  gt' (Value (Integer _)) val = throwError $ TypeMismatch "number" val
  gt' (Value (Float _)) val = throwError $ TypeMismatch "number" val
  gt' val _ = throwError $ TypeMismatch "number" val

gte :: PrimitiveFunc
gte = twoArgs gte'
 where
  gte' (Value (Integer i)) (Value (Integer i')) = return $ Bool $ i >= i
  gte' (Value (Integer i)) (Value (Float f)) = return $ Bool $ fromInteger i >= f
  gte' (Value (Float f)) (Value (Integer i)) = return $ Bool $ f >= fromInteger i
  gte' (Value (Float f)) (Value (Float f')) = return $ Bool $ f >= f
  gte' (Value (Integer _)) val = throwError $ TypeMismatch "number" val
  gte' (Value (Float _)) val = throwError $ TypeMismatch "number" val
  gte' val _ = throwError $ TypeMismatch "number" val

--
-- IO Primitives
--

ioPrimitives :: [(String, PrimitiveFunc)]
ioPrimitives = [ ("open-input-file", makePort ReadMode)
               , ("open-output-file", makePort WriteMode)
               , ("close-input-port", closePort)
               , ("close-output-port", closePort)
               , ("read-char", readChar)
               , ("read-line", readLine)
--             , ("read", readFromStdin)
               , ("write-char", writeChar)
               , ("write-string", writeString)
               , ("write", write)
--             , ("print", writeStringLine)
--             , ("flush", flushStdout)
               , ("read-char-from-port", readCharFromPort)
               , ("read-line-from-port", readLineFromPort)
--             , ("read-from-port", readFromPort)
               , ("write-char-to-port", writeCharToPort)
               , ("write-string-to-port", writeStringToPort)
               , ("write-to-port", writeToPort) ]
--             , ("print-to-port", writeStringLineToPort)
--             , ("flush-port", flushPort)
--             , ("get-lib-dir-name", getLibDirName) ]

makeIO :: IO EgisonValue -> EgisonValue
makeIO io = IOFunc . oneArg $ \val ->
  case val of
    Value World -> Tuple . (:) World . return <$> liftIO io
    _ -> throwError $ TypeMismatch "world" val

makeIO' :: IO () -> EgisonValue
makeIO' io = IOFunc . oneArg $ \val ->
  case val of
    Value World -> liftIO io >> return World
    _ -> throwError $ TypeMismatch "world" val

makePort :: IOMode -> PrimitiveFunc
makePort mode = oneArg $ \val -> do
  filename <- fromStringValue val 
  return . makeIO $ Port <$> openFile filename mode

closePort :: PrimitiveFunc
closePort = oneArg $ \val -> makeIO' . hClose <$> fromPortValue val

writeChar :: PrimitiveFunc
writeChar = oneArg $ \val -> makeIO' . putChar <$> fromCharValue val

writeString :: PrimitiveFunc
writeString = oneArg $ \val -> makeIO' . putStr <$> fromStringValue val

write :: PrimitiveFunc
write = oneArg $ Right . makeIO' . putStr . show

readChar :: PrimitiveFunc
readChar = noArg $ Right $ makeIO (liftM Char getChar)

readLine :: PrimitiveFunc
readLine = noArg $ Right $ makeIO (liftM String getLine)

writeCharToPort :: PrimitiveFunc
writeCharToPort = twoArgs $ \val val' ->
  (makeIO' .) . hPutChar <$> fromPortValue val <*> fromCharValue val'

writeStringToPort :: PrimitiveFunc
writeStringToPort = twoArgs $ \val val' ->
  (makeIO' .) . hPutStr <$> fromPortValue val <*> fromStringValue val'

writeToPort :: PrimitiveFunc
writeToPort = twoArgs $ \val val' ->
  makeIO' . flip hPutStr (show val') <$> fromPortValue val

readCharFromPort :: PrimitiveFunc
readCharFromPort = oneArg $ \val ->
  makeIO . liftM Char . hGetChar <$> fromPortValue val

readLineFromPort :: PrimitiveFunc
readLineFromPort = oneArg $ \val ->
  makeIO . liftM String . hGetLine <$> fromPortValue val

--
-- Assertions
--

assertions :: [(String, IOFunc)]
assertions = [ ("assert", assert)
             , ("assert-equal", assertEqual) ]

assert :: IOFunc 
assert [label, test] = do
  test <- liftError $ fromBoolValue test
  if test
    then return $ Bool True
    else throwError $ Assertion $ show label
assert vals = throwError $ ArgumentsNum 2 vals

assertEqual :: IOFunc 
assertEqual [label, actual, expected] = do
  actual <- evalDeep actual
  expected <- evalDeep expected
  if actual == expected
    then return $ Bool True
    else throwError $ Assertion $ show label ++ "\n expected: " ++ show expected ++
                                  "\n but found: " ++ show actual
assertEqual vals = throwError $ ArgumentsNum 3 vals
