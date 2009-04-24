
-- UUAGC 0.9.5 (TS_CoreSyntax.ag)
module TS_CoreSyntax where

import Top.Types

type Core_TypingStrategies = [Core_TypingStrategy]
-- Core_Judgement ----------------------------------------------
data Core_Judgement = Judgement (String) (Tp) 
                    deriving ( Read,Show)
-- Core_Judgements ---------------------------------------------
type Core_Judgements = [Core_Judgement]
-- Core_TypeRule -----------------------------------------------
data Core_TypeRule = TypeRule (Core_Judgements) (Core_Judgement) 
                   deriving ( Read,Show)
-- Core_TypingStrategy -----------------------------------------
data Core_TypingStrategy = Siblings ([String]) 
                         | TypingStrategy ([(String, Tp)]) (Core_TypeRule) (Core_UserStatements) 
                         deriving ( Read,Show)
-- Core_UserStatement ------------------------------------------
data Core_UserStatement = CorePhase (Int) 
                        | Equal (Tp) (Tp) (String) 
                        | MetaVariableConstraints (String) 
                        | Pred (String) (Tp) (String) 
                        deriving ( Read,Show)
-- Core_UserStatements -----------------------------------------
type Core_UserStatements = [Core_UserStatement]