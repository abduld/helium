-- do not edit; automatically generated by UU_AG
module TS_Syntax where

import UHA_Syntax
-- Judgement ---------------------------------------------------
data Judgement = Judgement_Judgement (Expression) (Type)
-- SimpleJudgement ---------------------------------------------
data SimpleJudgement = SimpleJudgement_SimpleJudgement (Name) (Type)
-- SimpleJudgements --------------------------------------------
type SimpleJudgements = [(SimpleJudgement)]
-- TypeRule ----------------------------------------------------
data TypeRule = TypeRule_TypeRule (SimpleJudgements) (Judgement)
-- TypingStrategies --------------------------------------------
type TypingStrategies = [(TypingStrategy)]
-- TypingStrategy ----------------------------------------------
data TypingStrategy = TypingStrategy_TypingStrategy (String) (TypeRule) (UserConstraints)
-- UserConstraint ----------------------------------------------
data UserConstraint = UserConstraint_UserConstraint (Type) (Type) (String)
-- UserConstraints ---------------------------------------------
type UserConstraints = [(UserConstraint)]

