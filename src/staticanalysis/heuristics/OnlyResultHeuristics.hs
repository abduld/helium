-----------------------------------------------------------------------------
-- The Helium Compiler : Static Analysis
-- 
-- Maintainer  :  bastiaan@cs.uu.nl
-- Stability   :  experimental
-- Portability :  unknown
--
-- Two (filter) heuristics that prevent an application or a negation to be 
-- reported as incorrect if only the result type is reponsible for non-unifiability.
--
-----------------------------------------------------------------------------

module OnlyResultHeuristics where

import Top.TypeGraph.Heuristics
import Top.States.TIState
import Top.Types
import OneLiner (OneLineTree)
import UHA_Syntax (Range)
import UHA_Source
      
-----------------------------------------------------------------------------

class MaybeApplication a where
   maybeNumberOfArguments :: a -> Maybe Int
   maybeApplicationEdge   :: a -> Maybe (Bool, [(UHA_Source, Tp)])

class IsPattern a where
   isPattern :: a -> Bool
   
applicationResult :: (HasTwoTypes info, MaybeApplication info) => Heuristic info
applicationResult = 
   Heuristic (edgeFilter "Only the result of an application edge" f) where
   
  f (edge, _, info) = 
   case maybeNumberOfArguments info of
      Nothing -> return True
      Just nrArgs ->
       doWithoutEdge (edge,info) $

          do synonyms <- getTypeSynonyms                 
             (maybeFunctionType, maybeExpectedType) <- getSubstitutedTypes info  
             case (maybeFunctionType,maybeExpectedType) of    
                (Just functionType,Just expectedType) -> return (not onlyResult)               
                   
                  where 
                    onlyResult = length xs == nrArgs &&
                                 length ys == nrArgs &&           
                                 unifiable synonyms (tupleType xs) (tupleType ys)                    
                    xs         = fst (functionSpineOfLength nrArgs functionType)
                    ys         = fst (functionSpineOfLength nrArgs expectedType)  
                _ -> return True  


-----------------------------------------------------------------------------

class MaybeNegation a where
   maybeNegation :: a -> Maybe Bool

negationResult :: (HasTwoTypes info, MaybeNegation info) => Heuristic info
negationResult = 
   Heuristic (edgeFilter "Only the result of a negation edge" f) where
  
  f (edge, _, info) =
   case maybeNegation info of
      Nothing -> return True
      Just isIntNegation -> doWithoutEdge (edge,info) $  
            do synonyms <- getTypeSynonyms
               (_, mtp) <- getSubstitutedTypes info
               case mtp of                   
                  Just tp -> 
                     let newtvar = TVar (nextFTV tp)
                         testtp = (if isIntNegation then intType else floatType) .->. newtvar
                     in return (not (unifiable synonyms tp testtp))
                  _ -> return True                          

-----------------------------------------------------------------------------
