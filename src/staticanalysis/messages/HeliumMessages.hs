-------------------------------------------------------------------------------
--
--   *** The Helium Compiler : Static Analysis ***
--               ( Bastiaan Heeren )
--
-- HeliumMessages.hs : ...
-- 
-------------------------------------------------------------------------------

module HeliumMessages where

import Messages 
import Types
import qualified PPrint
import qualified OneLiner
import List                (intersperse, zipWith4)
import TypesToAlignedDocs  (qualifiedTypesToAlignedDocs)
import UHA_Range           (isImportRange, showRanges)
import Char                (isSpace)

sortAndShowMessages :: HasMessage a => [a] -> String
sortAndShowMessages = concatMap showMessage . sortMessages

lineLength :: Int
lineLength = 80

instance Show MessageLine where
   show messageLine = 
      case prepareTypesAndTypeSchemes messageLine of
         MessageOneLiner m   -> show m++"\n"
         MessageTable tab    -> showTable tab
         MessageHints pre ms -> showHints pre ms

instance Show MessageBlock where
   show (MessageString s     ) = s
   show (MessageRange r      ) = show r
   show (MessageType tp      ) = show tp
   show (MessageTypeScheme ts) = show ts
   show (MessageKind kind    ) = showKind kind
   show (MessagePredicate p  ) = show p
   show (MessageOneLineTree t) =  -- see tableWidthRight
                                 OneLiner.showOneLine 58 t
   show (MessageInfoLink s   ) = "" -- "<a link=" ++ s ++ ">[?]</a>"
   show (MessageCompose ms   ) = concatMap show ms

showMessage :: HasMessage message => message -> String
showMessage x =
    let rangePart = MessageString $ case filter (not . isImportRange) (getRanges x) of
                       [] -> ""
                       xs -> showRanges xs ++ ": "
        documentationLinkPart = maybe (MessageString "") MessageInfoLink (getDocumentationLink x)
        list = case getMessage x of
                  MessageOneLiner m:rest -> MessageOneLiner (MessageCompose [rangePart, documentationLinkPart, m]) : rest
                  xs                     -> MessageOneLiner (MessageCompose [rangePart, documentationLinkPart]) : xs
    in concatMap show list

showHints :: String -> MessageBlocks -> String
showHints pre ms =
   let firstPrefix = "  " ++ pre ++ ": "
       restPrefix  = replicate (4 + length pre) ' '
       width       = lineLength - length firstPrefix
       combine     = concat . intersperse ("\n" ++ restPrefix)
       prefixes    = firstPrefix : repeat restPrefix
   in unlines . zipWith (++) prefixes . map (combine . splitString width . show) $ ms

tableWidthLeft :: Int
tableWidthLeft = 16

tableWidthRight :: Int
tableWidthRight = lineLength - tableWidthLeft - 7 -- see leftStars and middleSep

showTable :: [(MessageBlock, MessageBlock)] -> String
showTable = let leftStars = " "
                middleSep = " : "
                showTuple (x, y) =
                   let tableWidthLeft'| isTypeOrTypeSchemeMessage y = tableWidthLeft - 2
                                      | otherwise                   = tableWidthLeft
                       zipf a b c d = a ++ b ++ c ++ d
                       xs  = splitString tableWidthLeft  (show x)
                       ys  = splitString tableWidthRight (show y)
                       i   = length xs `max` length ys
                       xs' = map (\s -> take tableWidthLeft' (s++repeat ' ')) (xs ++ repeat "")
                       ys' = ys ++ repeat (replicate tableWidthRight ' ')
                       left   | isTypeOrTypeSchemeMessage y = repeat (replicate (length leftStars + 2) ' ')
                              | otherwise                   = leftStars : repeat (replicate (length leftStars) ' ')
                       middle = middleSep : repeat "   "
                   in unlines (take i (zipWith4 zipf left xs' middle ys'))
            in concatMap showTuple . renderTypesInRight tableWidthRight

isTypeOrTypeSchemeMessage :: MessageBlock -> Bool
isTypeOrTypeSchemeMessage mb =
   case mb of
      MessageType _       -> True
      MessageTypeScheme _ -> True
      MessageKind _       -> True
      MessagePredicate _  -> True
      _                   -> False

-- if two types or type schemes follow each other in a table (on the right-hand side)
-- then the two types are rendered in a special way.
renderTypesInRight :: Int -> [(MessageBlock, MessageBlock)] -> [(MessageBlock, MessageBlock)]
renderTypesInRight width table =
   case table of
      (l1, r1) : (l2, r2) : rest
        -> case (maybeQType r1, maybeQType r2) of
              (Just tp1, Just tp2) -> let [doc1, doc2] = qualifiedTypesToAlignedDocs [tp1, tp2]
                                          render = flip PPrint.displayS [] . PPrint.renderPretty 1.0 width
                                      in (l1, MessageType ([] :=> TCon (render doc1)))
                                       : (l2, MessageType ([] :=> TCon (render doc2)))
                                       : renderTypesInRight width rest
              _                    -> (l1, r1) : renderTypesInRight width ((l2, r2) : rest)
      _ -> table

  where maybeQType :: MessageBlock -> Maybe QType
        maybeQType (MessageType qtype   ) = Just qtype
        maybeQType (MessageTypeScheme ts) = Just (getQualifiedType ts) -- unsafe?
        maybeQType _                      = Nothing

-- make sure that a string does not exceed a certain width.
-- Two extra features:
--   - treat '\n' in the proper way.
--     (Be careful here: an enter in a string or a character does not
--      make a new line)
--   - try not to break words.
splitString :: Int -> String -> [String]
splitString width = concatMap f . lines
   where f string | length string <= width
                    = [string]
                  | otherwise
                    = let lastSpace     = last . (width:) . map fst . filter predicate
                                               . zip [0..] . take width $ string
                          predicate (pos, char) = isSpace char && pos >= width - splitStringMargin
                          (begin, rest) = splitAt lastSpace string
                      in begin : f (dropWhile isSpace rest)
                    
splitStringMargin :: Int
splitStringMargin = 15

-- Prepare the types and type schemes in a messageline to be shown.
--
-- type schemes:
--   * responsible for their own type variables
--   * monomorphic type variables are frozen, that is, replaced by _1, _2, etc.
-- types: 
--   * use a, b, c for type variables
--   * use the type variables consistent over all types 
--       (for instance, all v5 are mapped to a 'c')
prepareTypesAndTypeSchemes :: MessageLine -> MessageLine
prepareTypesAndTypeSchemes messageLine = newMessageLine
   where 
    (result, _, names) = replaceTypeSchemes messageLine
    newMessageLine     = giveTypeVariableIdentifiers result
   
     --step 1
    replaceTypeSchemes :: MessageLine -> (MessageLine, Int, [String])
    replaceTypeSchemes messageLine = 
       let unique = nextFTV messageLine
       in case messageLine of
             MessageOneLiner mb -> let (r, i, ns) = f_MessageBlock unique mb
                                   in (MessageOneLiner r, i, ns)
             MessageTable tab   -> let (r, i, ns) = f_Table unique tab
                                   in (MessageTable r, i, ns)
             MessageHints s mbs -> let (r, i, ns) = f_MessageBlocks unique mbs
                                   in (MessageHints s r, i, ns)

    --step 2
    giveTypeVariableIdentifiers :: MessageLine -> MessageLine
    giveTypeVariableIdentifiers ml = 
       let sub = listToSubstitution (zip (ftv ml) [ TCon s | s <- variableList, s `notElem` names])
       in sub |-> ml
   
    f_Table :: Int -> [(MessageBlock, MessageBlock)] -> ([(MessageBlock, MessageBlock)], Int, [String])
    f_Table i [] = ([], i, [])
    f_Table i ((a, b):xs) = let (r1, i1, ns1) = f_MessageBlock i  a
                                (r2, i2, ns2) = f_MessageBlock i1 b
                                (r3, i3, ns3) = f_Table        i2 xs
                            in ((r1, r2):r3, i3, ns1++ns2++ns3)    
    
    f_MessageBlocks :: Int -> [MessageBlock] -> ([MessageBlock], Int, [String])
    f_MessageBlocks i []     = ([], i, [])
    f_MessageBlocks i (x:xs) = let (r1, i1, ns1) = f_MessageBlock  i  x
                                   (r2, i2, ns2) = f_MessageBlocks i1 xs
                               in (r1:r2, i2, ns1++ns2)

    f_MessageBlock :: Int -> MessageBlock -> (MessageBlock, Int, [String])
    f_MessageBlock unique messageBlock = 
        case messageBlock of
           MessageCompose mbs   -> let (r, i, ns) = f_MessageBlocks unique mbs
                                   in (MessageCompose r, i, ns)
           MessageTypeScheme ts -> let (unique', ps, its) = instantiateWithNameMap unique ts
                                   in (MessageType (ps :=> its), unique', constantsInType its)
           _                    -> (messageBlock, unique, [])
