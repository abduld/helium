module PhaseLexer(phaseLexer) where

import CompileUtils
import LexerToken(Token)
import Lexer(lexer)
import LayoutRule(layout)
import LexerMessage(LexerWarning)

phaseLexer :: String -> String -> [Option] -> 
                IO ([LexerWarning], [Token])
phaseLexer fullName contents options = do
    enterNewPhase "Lexing" options

    case lexer fullName contents of 
        Left lexError -> do
            unless (NoLogging `elem` options) $ 
                logger "L" Nothing
            showErrorsAndExit [lexError] 1 options
        Right (tokens, lexerWarnings) -> do
            let tokensWithLayout = layout tokens
            when (DumpTokens `elem` options) $ do
                putStrLn (show tokensWithLayout)
            return (lexerWarnings, layout tokens)

