#This script is used to quickly analuyze entitlement data pulled from SailPoint IdenityIQ using the Entitlement Analysis feature
#In order for this to work out of the box, your CSV will need the following Column headers: Application, Value, First Name, Last Name

'''First ensure that you are directing the script to read a CSV file you wish to use by updating the file path below
Also ensure you update the file output path at the bottom of the script as well'''

$file = Import-Csv "#Path Here"

#Below are some variables we will generate, but be sure to set the "pct" (percent) variable manually to a value you feel is relevant for analysis.
#EX: If you have a group of 80 users you may feel that any entitlement held by 1/3 or more of users is relevant, so you set $pct to .33

$Global:count = 0
$Global:users = ""
$final_ent_list = @()
$excluded_ent_list = @()
$pct = .33

#These next variables we particullary usefule on a specific client project, but may not be usefule to you. If so, leave the arrays empty

#Below is an array we can use to list any Active Directory entitlemements we wish to ingnore, such as Domain Users. This list can be updated as needed with comma seperated values.

$AD_ignore =@('Domain Users')

#Below is an array we can use to list any Applications we do not wish to include in our Analysis as they may be unable to be automated, not suitable for RBAC, etc.
$APP_ignore = @()

#This section is simply used to get a count of all unique identities in our CSV file so we can check the percentage of how many users hold an entitlement (based on $pct set above)

$all_users = @()

ForEach($line in $file){
    $identity = $line.Identity
    $all_users += $identity
    }

$all_unique = $all_users | Select-Object -Unique
$total_users = $all_unique.count

#Now we will sort through all entitlements and gather a count of how many times and entitlement appears and the names of the users who hold the entitlement

ForEach($line in $file){
    #This line checks for the applications we wish to ignore and skips those lines
    If($APP_ignore.Contains($line.Application)){Continue}
    #If there is only 1 user in the file we will simply walk through the entitlements and filter out those we do not wish to see.
    If($total_users -eq 1){
        $app = $line.Application
        $entitlement = $line.Value
        If($AD_ignore.Contains($entitlement)){Continue}
    }
    Else{
        $name = $line.'First Name' + ' ' + $line.'Last Name'
        $entitlement_info = [pscustomobject]@{
            Application = $app
            Entitlement = $entitlement
            'Entitlement Count' = $total_users
            Users = $name
            }
        $final_ent_list += $entitlement_info
    }

'''If not found in the initial application check, and if there is more than one user, we are to create variables for each relevant column in a row we want
to see the data for, and then increase the count by 1 to store the information for a specific application and entitlement combination'''

    ElseIf($Global:count -eq 0){
        $app = $line.Application
        $entitlement = $line.Value
        $Global:count += 1
        $name = $line.'First Name' + ' ' + $line.'Last Name'
        $Global:users += $name
    }

'''This next section is used to check and see if the next line in the file is the same application and entitlement value as the previous or if we need to stop
counting and begin a new entry for a new, unique entitlement'''

    ElseIf($Global:count -eq 1){
        #If the current stored entitlement value does not match the next line, here we account for any instance of only a single entitlement entry
        If($entitlement -ne $line.Value){
            $Global:users += $name
            $entitlement_info = [pscustomobject]@{
                Application = $app
                Entitlement = $entitlement
                'Entitlement Count' = $total_users
                Users = $Global:users
            }
        '''Here we will check to see if we have ser the percentage value low enough to only include a single user. EX: a $pct value of .1 would still
        be capture 1 user in a population of 10'''
            If($Global:count/$total_users -gt $pct){
                If($AD_ignore.Contains($entitlement){
                    #set values to capture the current line information
                    $entitlement = $line.Value
                    $app = $line.Application
                    $name = $line.'First Name' + ' ' + $line.'Last Name'
                    #set count to 1 so that we capture the next entitlement count
                    $Global:count = 1
                    $Global:users = ""
                    Continue
                }
                Else{
                    $entitlement_info = [pscustomobject]@{
                        Application = $app
                        Entitlement = $entitlement
                        'Entitlement Count' = $total_users
                        Users = $Global:users
                    }
                    $final_ent_list += $entitlement_info
                }
            }
            Else{
                $excluded_ent_list += $entitlement_info
            }
        '''After this we are setting the variable used to refelect the current row so we can check it against the next row. Without this the count would be off
        by one as it immediately looks to the next line. We will also reset the $Global:Users variable to be an empty string as sent the $Global:count to 1 to
        reflect at least a single entry of an application and entitlement combination'''

        $entitlement = $line.Value
        $app = $line.Application
        $name = $line.'First Name' + ' ' + $line.'Last Name'
        $Global:users = ""
        $Global:count = 1
    }
    #If the current stored entitlement DOES match the next line, we increase the count and move to the next iteration
    Else{
        $Global:count += 1
        #This checks to see if it is the second instance of an entitlement to correctly format the string value for the list of names tied to an entitlement
        If($Global:count -eq 2){
            $Global:users += $name + ', ' + $line.'First Name' + ' ' + $line.'Last Name'
        }
        Else{
            $Global:users += ', ' + $line.'First Name' + ' ' + $line.'Last Name'
        }
    }
Else{
    If($entitlement -eq $line.Value){
        $Global:count += 1
        $name = $line.'First Name' + ' ' + $line.'Last Name'
        $Global:users += $name
    }
    Else{
        If($AD_ignore.Contains($entitlement){
            #set values to capture the current line information for appliction, name, and entitlement so it does not get skipped
            $entitlement = $line.Value
            $app = $line.Application
            $name = $line.'First Name' + ' ' + $line.'Last Name'
            #set count to 1 so that we capture the next entitlement count
            $Global:count = 1
            $Global:users = ""
            Continue
        }
        ElseIf($Global:count/$total_users -gt $pct){
            $entitlement_info = [pscustomobject]@{
                Application = $app
                Entitlement = $entitlement
                'Entitlement Count' = $total_users
                Users = $Global:users
            }
            $final_ent_list += $entitlement_info
            #set values to capture the current line information for applicaiton, name, and entitlement so it does not get skipped
            $entitlement = $line.Value
            $app = $line.Application
            $name = $line.'First Name' + ' ' + $line.'Last Name'
            #set count to 1 so that we capture the next entitlement count
            $Global:count = 1
            $Global:users = ""
            Continue
        }
        Else{
            $entitlement_info = [pscustomobject]@{
                Application = $app
                Entitlement = $entitlement
                'Entitlement Count' = $total_users
                Users = $Global:users
            }
            $excluded_ent_list += $entitlement_info
            #set values to capture the current line information for applicaiton, name, and entitlement so it does not get skipped
            $entitlement = $line.Value
            $app = $line.Application
            $name = $line.'First Name' + ' ' + $line.'Last Name'
            #set count to 1 so that we capture the next entitlement count
            $Global:count = 1
            $Global:users = ""
            Continue
           }
        }
    }
}

$final_ent_list | Export-Csv -Path '#path and file name here' -Delimiter ',' -NoTypeInformation
#If there is only one user we do not need the excluded list so we will not output this file
If($total_users -gt 1){
    $excluded_ent_list Export-Csv -Path '#path and file name here' -Delimiter ',' -NoTypeInformation