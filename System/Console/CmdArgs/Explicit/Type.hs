
module System.Console.CmdArgs.Explicit.Type where

import Data.Char
import Data.List
import Data.Maybe
import Control.Monad


boolTrue = ["true","yes","on","enabled","1"]
boolFalse = ["false","no","off","disabled","0"]


type Name = String
type Help = String
type FlagHelp = String



data HelpInfo = HelpInfo
    {helpProgram :: Maybe String -- ^ The program name to use
    ,helpWidth :: Maybe Int -- ^ The help width to use
    ,helpSuffix :: [String] -- ^ The help message to print at the end
    }

helpInfo = HelpInfo Nothing Nothing []


-- | If a default mode is given, and no other modes, then that one is always used.
data Mode a
    = Modes
        {modesDefault :: Maybe ([Name], Mode a) -- ^ A default mode
        ,modesRest :: [([Name], Mode a)] -- ^ The available modes (do not include 'modeDefault')
        }
    | Mode
        {modeValue :: a -- ^ Value to start with
        ,modeHelp :: Help -- ^ Help text
        ,modeGroups :: [(String,[Flag a])] -- ^ Groups of flags, [("",xs)] for all in same group
        }

modesAll :: Mode a -> [([Name],Mode a)]
modesAll x = maybeToList (modesDefault x) ++ modesRest x

modeFlags :: Mode a -> [Flag a]
modeFlags = concatMap snd . modeGroups


{-|
The 'FlagArg' type has the following meaning:

             ArgReq      ArgOpt       ArgOptRare/ArgNone
-xfoo        -x=foo      -x=foo       -x= -foo
-x foo       -x=foo      -x foo       -x= foo
-x=foo       -x=foo      -x=foo       -x=foo
--xx foo     --xx=foo    --xx foo      --xx foo
--xx=foo     --xx=foo    --xx=foo      --xx=foo
-}
data FlagArg
    = ArgReq             -- ^ Required argument
    | ArgOpt String      -- ^ Optional argument
    | ArgOptRare String  -- ^ Optional argument that requires an = before the value
    | ArgNone            -- ^ No argument

fromArgOpt (ArgOpt x) = x
fromArgOpt (ArgOptRare x) = x

data FlagInfo
    = FlagNamed
        {flagNamedArg :: FlagArg
        ,flagNamedNames :: [Name]}
    | FlagUnnamed
    | FlagPosition Int -- ^ 0 based

type Update a = String -> a -> Either String a

data Flag a = Flag
    {flagInfo :: FlagInfo
    ,flagValue :: Update a
    ,flagType :: FlagHelp -- the type of data for the user, i.e. FILE/DIR/EXT
    ,flagHelp :: Help
    }


---------------------------------------------------------------------
-- FLAG CREATORS

flagNone :: [Name] -> (a -> a) -> Help -> Flag a
flagNone names f help = Flag (FlagNamed ArgNone names) upd "" help
    where upd _ x = Right $ f x

flagOptional :: String -> [Name] -> Update a -> FlagHelp -> Help -> Flag a
flagOptional def names upd typ help = Flag (FlagNamed (ArgOpt def) names) upd typ help

flagRequired :: [Name] -> Update a -> FlagHelp -> Help -> Flag a
flagRequired names upd typ help = Flag (FlagNamed ArgReq names) upd typ help

flagUnnamed :: Update a -> FlagHelp -> Flag a
flagUnnamed upd typ = Flag FlagUnnamed upd typ ""

flagPosition :: Int -> Update a -> FlagHelp -> Flag a
flagPosition pos upd typ = Flag (FlagPosition pos) upd typ ""


flagBool :: (Bool -> a -> a) -> [Name] -> Help -> Flag a
flagBool f names help = Flag (FlagNamed (ArgOptRare "") names) upd "" help
    where upd s x = if s == "" || ls `elem` boolTrue then Right $ f True x
                    else if ls `elem` boolFalse then Right $ f False x
                    else Left "expected boolean value (true/false)"
                where ls = map toLower s


---------------------------------------------------------------------
-- MODE/MODES CREATORS

mode :: a -> Help -> [Flag a] -> Mode a
mode value help flags = Mode value help [("",flags)]

modes :: [([Name],Mode a)] -> Mode a
modes xs = Modes Nothing xs


---------------------------------------------------------------------
-- CHECK FLAGS

-- | The 'modeNames' values are distinct between different modes.
--   The names/positions/arbitrary are distinct within one mode
checkMode :: Mode a -> Maybe String
checkMode x@Modes{} =
    (noDupes "modes" $ concatMap fst $ modesAll x) `mplus`
    (check "No other modes given" $ not $ null $ modesRest x) `mplus`
    msum (map (checkMode . snd) $ modesAll x)

checkMode x@Mode{} =
    (noDupes "flag names" [y | FlagNamed _ y <- xs]) `mplus`
    (check "Duplicate unnamed flags" $ unnamed > 1) `mplus`
    (noDupes "flag positions" positions) `mplus`
    (check "Positions are non-sequential" $ unnamed > 0 || positions `isPrefixOf` [0..])
    where xs = map flagInfo $ modeFlags x
          unnamed = length [() | FlagUnnamed <- xs]
          positions = [y | FlagPosition y <- xs]


noDupes :: (Eq a, Show a) => String -> [a] -> Maybe String
noDupes msg xs = do
    bad <- listToMaybe $ xs \\ nub xs
    let dupe = filter (== bad) xs
    return $ "Sanity check failed, multiple " ++ msg ++ ": " ++ unwords (map show dupe)


check :: String -> Bool -> Maybe String
check msg True = Nothing
check msg False = Just msg
