{-# LANGUAGE DeriveDataTypeable #-}

import System.Console.CmdArgs

data DirDiff = Create {src :: FilePath, out :: FilePath}
             | Diff {old :: FilePath, new :: FilePath, out :: FilePath}
               deriving (Data,Typeable,Show)


outFlags = text "Output file" & typFile

create = Create
    {src = "." & text "Source directory" & typDir
    ,out = "ls.txt" & outFlags
    } & text "Create a fingerprint"

diff = Diff
    {old = def & argPos 0
    ,new = def & argPos 1
    ,out = "diff.txt" & outFlags
    } & text "Perform a diff"


main = print =<< cmdArgsMode "DirDiff v1.0" [create,diff]
