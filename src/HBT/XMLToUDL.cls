Include Utils.HBTLib

/// This class offers the functionality to transform a studio export file (.xml) into UDL sources (.cls, .hl7, .lut etc.) and to set up a directory and folder structure.
Class HBT.XMLToUDL
{

Parameter WORKINGDIRECTORY = "/irisrun/udl-export";

/// This method is the entrypoint for the transformation of the studio export file into UDL sources.
ClassMethod ImportUDLFromDefault() As %Status
{
    #Dim tSC As %Status
    #Dim tSE As %Exception.StatusException
    #Dim tLocation as %String
    #Dim tFixedLocation as %String
    #Dim tImportedItems as %String // CSV list of imported items

    Try {
        Set tLocation = "/irisrun/export.xml"
        Set tFixedLocation = "/opt/irisbuild/export-fixed.xml"
        Set tWorkingDirectory = ..#WORKINGDIRECTORY
        If '##class(%File).DirectoryExists(tWorkingDirectory) {
		    $$$ThrowOnError(##class(%File).CreateDirectoryChain(tWorkingDirectory))
	    }
        $$$ThrowOnError(##class(Utils.CustomizedHelper).FixExportFile(tLocation, tFixedLocation))
        $$$ThrowOnError($SYSTEM.OBJ.Load(tFixedLocation,"",.%errorlog,.tImportedItems,0,,))
        $$$ThrowOnError(..ExportFiles(tImportedItems))
        Set tSC = $$$OK
    } Catch tSE {
        Set tSC = tSE.AsStatus()
        Quit
    }
    Quit tSC
}

/// This method triggers the export process for every item in the export, after it's verified that the item is not part of a ignore list. 
ClassMethod ExportFiles(pImportedItems As %String) As %Status
{
    #Dim tSC As %Status
    #Dim tSE As %Exception.StatusException
    #Dim tItemList As List of %String
    #Dim tItemName As %String
    #Dim tIgnoreItem As %Boolean

    Try {
        Set tItemList = $LISTFROMSTRING(pImportedItems, ",")
        For i=1:1:$LISTLENGTH(tItemList) {
            Set tItemName = $LIST(tItemList, i)
            $$$ThrowOnError(##class(Utils.CustomizedHelper).GetIgnoreStatus(tItemName, .tIgnoreItem))
            If (tIgnoreItem) {
                Write !,"Skip exporting file because it is on a ignore list: ", tItemName,!
            } Else {
                $$$ThrowOnError(..ExportItem(tItemName))
            }
        }
        Set tSC = $$$OK
    } Catch tSE {
        Set tSC = tSE.AsStatus()
        Quit
    }
    Quit tSC
}

/// This method checks the file type and decides which export method must be used to export the corresponding item.
ClassMethod ExportItem(pItemName As %String) As %Status
{
    #Dim tSC As %Status
    #Dim tSE As %Exception.StatusException
    #Dim tClassAndRoutinesExtensions As List of %String
    #Dim tCommonItemTypeExtensions As List of %String
    #Dim tItemExtension As %String
    
    Try {
        Write !,"Exporting File: ", pItemName,!
        Set tClassAndRoutinesExtensions = $LISTBUILD("cls", "mac", "int", "inc")
        Set tCommonItemTypeExtensions = $LISTBUILD("hl7","csp","lut")
        Set tItemExtension = $$$GetExtension(pItemName)
        $$$ThrowOnError(..CreateFileName(pItemName, .tFileName))
        $$$ThrowOnError(..CreateDirectory(tFileName))
        If $LISTFIND(tClassAndRoutinesExtensions, tItemExtension) {
            $$$ThrowOnError(##class(Utils.CustomizedHelper).GetClassStatus(pItemName, .tSkipItem))
            If (tSkipItem) {
                Write !,"Skip exporting class because it is generated, mapped or a %-class: ", pItemName,!
            } Else {
            // trigger export of classes and routines
            $$$ThrowOnError($SYSTEM.OBJ.ExportUDL(pItemName, tFileName))
            }
        } Else {
            // trigger export of other items (for example .hl7 or .lut files)
            If '$LISTFIND(tCommonItemTypeExtensions, tItemExtension) {
                Set pItemName = $REPLACE(pItemName,"-","/") // needed for .dfi files 
            }
            $$$ThrowOnError(##class(Utils.CustomizedHelper).FixXMLLine(pItemName, tFileName))
        }
        Set tSC = $$$OK
    } Catch tSE {
        Set tSC = tSE.AsStatus()
        Quit
    }
    Quit tSC
}

/// This method creates the file name and therefore it is the foundation to generate the path to set up the directory structure.
ClassMethod CreateFileName(pItemName As %String, Output oFileName As %String) As %Status
{
    #Dim tSC As %Status
    #Dim tSE As %Exception.StatusException
    #Dim tWorkingDirectory As %String
    #Dim tExtension As %String
    #Dim tDirectory As %String

    Try {
        Set tWorkingDirectory = ..#WORKINGDIRECTORY
        Set tExtension = $$$GetExtension(pItemName)
        // don't split HL7 schema files by dots
        If (tExtension '= "hl7") {
            Set tDirectory = $PIECE(pItemName, ".",1, *-2 )
            Set tDirectory = $TRANSLATE(tDirectory, ".", "/")
            Set pItemName = tDirectory_"/"_$PIECE(pItemName, ".", *-1, *)
        }
        Set oFileName = ##class(%File).NormalizeFilename(pItemName, tWorkingDirectory)
        If (tExtension = "dfi") {
            Set oFileName = $EXTRACT(oFileName,1,*-4)_".xml"
        }
        // make sure that the files are stored in the "src" directory of the project 
        If ('$FIND(oFileName, tWorkingDirectory)) {
            Set oFileName = tWorkingDirectory_oFileName
        }
        Write "Filename: ",oFileName,!
        Set tSC = $$$OK
    }
    Catch tSE {
            Set tSC = tSE.AsStatus()
            Quit
        }
    Quit tSC
}

/// This method creates the directory structure for a specific file if it it does not exist yet.
ClassMethod CreateDirectory(pFileName As %String) As %Status
{
    #Dim tSC As %Status
    #Dim tSE As %Exception.StatusException
    #Dim tPath As %String
    #Dim tPathToCreate As %String

    Try {
        Set tWorkingDirectory = ..#WORKINGDIRECTORY
        Set tPath = ##class(%File).GetDirectory(pFileName)
        If ($$$StringEndsWith(tPath, "/")) {
            Set tPath = $$$StringRemoveLast(tPath)
        }
        If '##class(%File).DirectoryExists(tPath){
            If ('$$$StringStartsWith(tPath, tWorkingDirectory)) {
                Set tPathToCreate = tWorkingDirectory_tPath
            } Else {
                Set tPathToCreate = tPath
            }
            Write !, "Directory does not exist. Creating: "_tPathToCreate, ! 
            $$$ThrowOnError(##class(%File).CreateDirectoryChain(tPathToCreate))
	    }
        Set tSC = $$$OK
    } Catch tSE {
        Set tSC = tSE.AsStatus()
        Quit
    }
    Quit tSC
}

}
