Param(
    [string]$configFile,
    [switch]$debug = $false
)

$cmdPath = "$PSScriptRoot\flyway.cmd"
$appEnv
$command
$config

function ShowUsage([String] $errorMessage) {
    Write-Host "`n$errorMessage`n" -ForegroundColor Red
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "   flyway <<configFile>> [-debug]`n" -ForegroundColor Cyan
    Write-Host "Where <<configFile>> is the path to the specified JSON or XML application environment configuration file.`n" -ForegroundColor Cyan
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "   flyway myApp.xml" -ForegroundColor Cyan
    Write-Host "   flyway myApp.json -debug`n" -ForegroundColor Cyan
}

function LoadEnvironmentDetails(){
    if ( [string]::IsNullOrEmpty($configFile))
    {
        ShowUsage("No configuration file specified.")
        exit
    }
    elseif (-NOT(Test-Path $configFile))
    {
        ShowUsage("Unable to load configuration ($configFile) as file does not exist. Supported formats are JSON or XML.")
        exit
    }
    elseif ($configFile.EndsWith("xml"))
    {
        [xml]$config = Get-Content $configFile
    }
    elseif ( $configFile.EndsWith("json"))
    {
        $config = Get-Content -Raw -Path $configFile | ConvertFrom-Json
    }

    if ("$debug" -ne $config.app.global.debugEnabled ) {
        $config.app.global.debugEnabled = "$debug"
    }

    return $config
}

function DisplaySkipDefaultCallbacksPrompt(){
    $message = "`nSkip default SQL callbacks?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Skips the default SQL callbacks"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Execute the default callbacks"
    $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 1)

    $param = "false"
    switch ($result){
        0 {
            $param = "true"
        }
    }

    return  " -skipDefaultCallbacks=`"$param`" "
}

function DisplaySkipRepeatableMigrationsPrompt(){

    $message = "`nSkip repeatable migrations?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Bypasses the repeaable migrations"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Includes repeatable migrations"
    $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 1)

    $param = "R"
    switch ($result){
        0 {
            $param = "IGNORE_______"
        }
    }

    return  " -repeatableSqlMigrationPrefix=`"$param`" "

}

function DisplayTargetVersionMigratePrompt(){
    $message = "`nPlease enter the target version up to which Flyway should consider migrations (default: latest)"
    $default = "latest"
    $option = [string]::Empty

    do {

        $param = Read-Host -Prompt $message

        if ([string]::IsNullOrEmpty($param)){
            $param = $default;
        } else {
            # checks the value entered only contains 0..9 and .
            if ($param -match '(?m)^(\d+)((\.{1}\d+)*)(\.{0})$'){
                $option = " -target=`"$param`" "
            } else {
                Write-Host "`nERROR: Invalid version containing non-numeric characters. Only 0..9 and . are allowed. Invalid version: $param" -ForegroundColor Red
                $param = [string]::Empty
            }
        }

    } while ([string]::IsNullOrEmpty($param))

    return $option
}

function DisplayOutOfOrderMigrationsPrompt(){

    $message = "`nAllow migrations to be run out of order?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Allows migrations to be run out of order"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Ignore migration scripts which are out of order"
    $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 1)

    $param = "false"
    switch ($result){
        0 {
            $param = "true"
        }
    }

    return  " -outOfOrder=`"$param`" "

}

function DisplayValidateOnMigratePrompt(){

    $message = "`nValidate existing migration scripts?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Verify existing migration scripts still has the same checksum as the sql migration already executed in the database"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Skips the checksum validation on existing migration scripts"
    $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 0)

    $param = "true"
    switch ($result){
        1 {
            $param = "false"
        }
    }

    return  " -validateOnMigrate=`"$param`" "

}

function DisplayIgnoreMissingMigrationsPrompt(){

    $message = "`nIgnore missing migrations when validating?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Missing migrations will be highlighted as warnings when validating"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Fail validation when missing migrations are identified"
    $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 1)

    $param = "false"
    switch ($result){
        0 {
            $param = "true"
        }
    }

    return  " -ignoreMissingMigrations=`"$param`" "

}

function DisplayIgnoreFutureMigrationsPrompt(){
    $message = "`nIgnore future migrations when validating?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Future migrations will be highlighted as warnings when validating"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Fail validation when future migrations are identified in the schema history table but the script does not exist"
    $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 0)

    $param = "true"
    switch ($result){
        1 {
            $param = "false"
        }
    }

    return " -ignoreFutureMigrations=`"$param`" "
}

function DisplayIgnoreIgnoredMigrationsPrompt(){
    $message = "`nIgnore ignored migrations when validating?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Ignore migrations not added to the database which were added in between already migrated migrations."
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Validate all migrations against resolved migrations."
    $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 1)

    $param = "false"
    switch ($result){
        0 {
            $param = "true"
        }
    }

    return " -ignoreIgnoredMigrations=`"$param`" "
}

function DisplayBaselineVersionPrompt(){
    $message = "`nPlease enter the baseline version to tag an existing unversioned schema with (default: 1.0.0)"
    $default = "1.0.0"

    do {

        $param = Read-Host -Prompt $message

        if ([string]::IsNullOrEmpty($param)){
            $param = $default;
        } else {

            # checks the value entered only contains 0..9 and .
            if ($param -match '(?m)^(\d+)((\.{1}\d+)*)(\.{0})$'){
                $option = " -target=`"$param`" "
            } else {
                Write-Host "`nERROR: Invalid version containing non-numeric characters. Only 0..9 and . are allowed. Invalid version: $param" -ForegroundColor Red
                $param = [string]::Empty
            }
        }

    } while ([string]::IsNullOrEmpty($param))

    return " -baselineVersion=`"$param`" "
}

function DisplayBaselineDescriptionPrompt(){

    $message = "`nPlease enter the description to tag an existing unversioned schema with when executing baseline. (default: << Flyway Baseline >>)"
    $default = "<< Flyway Baseline >>"

    $param = Read-Host -Prompt $message

    if ([string]::IsNullOrEmpty($param)){
        $param = $default;
    }

    return " -baselineDescription=`"$param`" "
}



function ShowTopMenu(){
    $menuDisplayed = $false

    :OuterLoop do{

        if ($menuDisplayed -ne $true){
            Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan
            Write-Host " Main Menu" -ForegroundColor Cyan
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

            $menuDisplayed = $true
        }

        $admin = New-Object System.Management.Automation.Host.ChoiceDescription "&Admin", "Sets global admin settings"
        $environment = New-Object System.Management.Automation.Host.ChoiceDescription "&Environment", "Sets the working database evironment"
        $version = New-Object System.Management.Automation.Host.ChoiceDescription "&Version", "Displays the flyway version"
        $usage = New-Object System.Management.Automation.Host.ChoiceDescription "&Usage", "Disolays the flyway CLI usage"
        $quit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", "Exits the CLI."

        $options = [System.Management.Automation.Host.ChoiceDescription[]]($admin, $environment, $version, $usage, $quit)

        $message = "`nPlease select menu option:"
        $result = $host.ui.PromptForChoice('', $message, $options, 1)

        switch ($result){
            0 { #Admin
                $menuDisplayed = $false
                ShowAdminMenu
            }
            1 { #Environment
                $menuDisplayed = $false
                ShowEnvironmentMenu
            }
            2 { #version
                & $cmdPath "-v"
            }
            3 { #help
                Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan
                & $cmdPath "-?"
                Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan
            }
            4 { #Exit
                Write-Host "`nExiting the Flyway Database Migration CLI`n" -ForegroundColor Cyan
                break OuterLoop
            }
        }

    } while ($false -ne $true)
}

function ShowAdminMenu(){
    $menuDisplayed = $false
    :OuterLoop do{

        if ($menuDisplayed -ne $true){
            Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan
            Write-Host " Admin Menu" -ForegroundColor Cyan
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

            $menuDisplayed = $true
        }

        $view = New-Object System.Management.Automation.Host.ChoiceDescription "&View Config", "View the global admin parameters"
        $debug = New-Object System.Management.Automation.Host.ChoiceDescription "Set &Debug", "Set the global debug parameter for this session"
        $exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", "Returns to main menu"

        $options = [System.Management.Automation.Host.ChoiceDescription[]]($view, $debug, $exit)

        $message = "`nPlease select menu option:"
        $result = $host.ui.PromptForChoice('', $message, $options, 2)

        switch ($result){
            0 { #view config

                Write-Host "`n-> Global Configuration Paramaters" -ForegroundColor Cyan
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

                #Create Table object
                $table = New-Object system.Data.DataTable "Global Configuration Paramaters"

                #Define Columns
                $debugCol = New-Object system.Data.DataColumn "Debug Enabled",([string])
                $schemaVersionCol = New-Object system.Data.DataColumn "Schema Version",([string])
                $installedByCol = New-Object system.Data.DataColumn "Installed By",([string])

                #Add the Columns
                $table.columns.add($debugCol)
                $table.columns.add($schemaVersionCol)
                $table.columns.add($installedByCol)

                #Create a row
                $row = $table.NewRow()

                #Enter data in the row
                $row[0] = $config.app.global.debugEnabled
                $row[1] = $config.app.global.schemaHistoryTable
                $row[2] = $config.app.global.installedBy

                #Add the row to the table
                $table.Rows.Add($row)

                #Display the table
                $table | format-table -AutoSize

                Write-Host "`Note: To enable debugging for this session use the 'Set Debug' option or launch with -debug switch" -ForegroundColor Cyan
                Write-Host "`      To modify these settings update the configuration file ($configFile)" -ForegroundColor Cyan
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

            }
            1 { #debug

                $message = "`nDo you want to enable debug output for this session?"
                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Enabling debug will display debug output on the console."
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Supresses debug output to the console."
                $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 0)


                switch ($result) {
                    0 {
                        $config.app.global.debugEnabled  = "true"
                    }
                    1 {
                        $config.app.global.debugEnabled = "false"
                    }

                }

                Write-Host "`nDebug Enabled set to" $config.app.global.debugEnabled  -ForegroundColor Cyan

            }
            2 { #exit
                Write-Host "`nReturning to main menu" -ForegroundColor Cyan
                break OuterLoop
            }
        }

    } while ($false -ne $true)
}

function ShowEnvironmentMenu(){
    $menuDisplayed = $false

    :OuterLoop do{

        if ($menuDisplayed -ne $true){
            Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan
            Write-Host " Database Environment Selection Menu" -ForegroundColor Cyan
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

            $menuDisplayed = $true
        }


        # build the list of menu options based on the defined environments from the config file
        $options = @()
        foreach( $environment in $config.app.environments.environment){
            $envOption = New-Object System.Management.Automation.Host.ChoiceDescription $environment.name, $environment.description
            $options += $envOption
        }

        $exit = New-Object System.Management.Automation.Host.ChoiceDescription "e&xit", "Returns to main menu"
        $options += $exit

        $message = "`nPlease select the database environment:"
        $result = $host.ui.PromptForChoice('', $message, $options, 0)

        if ($result -eq $options.count - 1){
            Write-Host "`nReturning to main menu" -ForegroundColor Cyan
            break OuterLoop
        } else {
            $appEnv = @($config.app.environments.environment)[$result]
        }

        Write-Host "`nWorking database Environment set to" $appEnv.name  -ForegroundColor Cyan

        $menuDisplayed = $false
        ShowFlywayCommandsMenu

    } while ($false -ne $true)
}

function ShowFlywayCommandsMenu(){

    $menuDisplayed = $false
    $command = ""

    :OuterLoop do{
        if ($menuDisplayed -ne $true){
            Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan
            Write-Host " Flyway Database Command Menu - Working Environment [" -ForegroundColor Cyan -NoNewline
            Write-Host $appEnv.name -ForegroundColor Green -NoNewline
            Write-Host "]" -ForegroundColor Cyan
            Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

            $menuDisplayed = $true
        }

        # set the default options for flyway commands - if the command does not require these it will be overriden
        $url = " -url=" + $appEnv.connection.url
        $user = " -user=" + $appEnv.connection.user
        $password = " -password=" + $appEnv.connection.password
        $OFS = ','
        $locations = " -locations=" + ([string]$appEnv.locations.location)
        $OFS = $nul

        $migrate = New-Object System.Management.Automation.Host.ChoiceDescription "&migrate", "Migrates the database"
        $clean = New-Object System.Management.Automation.Host.ChoiceDescription "&clean", "Drops all objects in the configured schemas"
        $info = New-Object System.Management.Automation.Host.ChoiceDescription "&info", "Prints the information about applied, current and pending migrations"
        $validate = New-Object System.Management.Automation.Host.ChoiceDescription "&validate", "Validate applied migrations against resolved ones (on the filesystem or classpath) to detect accidental changes that may prevent the schema(s) from being recreated exactly."
        $baseline = New-Object System.Management.Automation.Host.ChoiceDescription "&baseline", "Baselines an existing database at the baselineVersion"
        $repair = New-Object System.Management.Automation.Host.ChoiceDescription "&repair", "Repairs the schema history table"
        $usage = New-Object System.Management.Automation.Host.ChoiceDescription "&usage", "Displays Flyway Help"
        $exit = New-Object System.Management.Automation.Host.ChoiceDescription "e&xit", "Returns to Envrironment Selecion Menu"

        $opts = @()
        $opts += $info
        $opts += $validate
        $opts += $repair
        $opts += $migrate
        $opts += $baseline
        $opts += $clean
        $opts += $usage
        $opts += $exit

        $message = "`nPlease select the flyway command to execute:"
        $result = $host.ui.PromptForChoice('', $message, $opts, 7)

        switch ($result){
            0 { #info
                Write-Host "`nCommand: INFO" -ForegroundColor DarkGray
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkGray
                Write-Host "Retrieves the complete information about all the migrations including applied, pending and current migrations with details and status." -ForegroundColor DarkGray

                $command =  "info"
            }
            1 { # validate
                Write-Host "`nCommand: VALIDATE" -ForegroundColor DarkGray
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkGray
                Write-Host "Validate applied migrations against resolved ones (on the filesystem or classpath) to detect accidental changes that may prevent the schema(s) from being recreated exactly." -ForegroundColor DarkGray
                Write-Host "Validation fails if:" -ForegroundColor DarkGray
                Write-Host "  - differences in migration names, types or checksums are found" -ForegroundColor DarkGray
                Write-Host "  - versions have been applied that aren't resolved locally anymore" -ForegroundColor DarkGray
                Write-Host "  - versions have been resolved that haven't been applied yet" -ForegroundColor DarkGray

               # $command = DisplayTargetVersionMigratePrompt
               # $command += DisplayOutOfOrderMigrationsPrompt
                $command = DisplayIgnoreMissingMigrationsPrompt
                $command += DisplayIgnoreFutureMigrationsPrompt
                $command += DisplayIgnoreIgnoredMigrationsPrompt
                $command +=  "validate"
            }
            2 { #repair

                Write-Host "`nCommand: REPAIR" -ForegroundColor DarkGray
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkGray
                Write-Host "Repairs the Flyway schema history table. This will perform the following actions:" -ForegroundColor DarkGray
                Write-Host "  - Remove any failed migrations on databases without DDL transactions (User objects left behind must still be cleaned up manually)" -ForegroundColor DarkGray
                Write-Host "  - Realign the checksums, descriptions and types of the applied migrations with the ones of the available migrations." -ForegroundColor DarkGray

                $command = "repair"
            }
            3 { #migrate

                Write-Host "`nCommand: MIGRATE" -ForegroundColor DarkGray
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkGray
                Write-Host "Starts the database migration. All pending migrations will be applied in order." -ForegroundColor DarkGray
                Write-Host "Calling migrate on an up-to-date database has no effect." -ForegroundColor DarkGray

                [string]$command = DisplayTargetVersionMigratePrompt
                $command += DisplaySkipRepeatableMigrationsPrompt
                $command += DisplaySkipDefaultCallbacksPrompt
                $command += DisplayOutOfOrderMigrationsPrompt
                $command += DisplayValidateOnMigratePrompt
                if ($command.Contains("-validateOnMigrate=`"true`"")){
                    $command += DisplayIgnoreMissingMigrationsPrompt
                    $command += DisplayIgnoreFutureMigrationsPrompt
                    $command += DisplayIgnoreIgnoredMigrationsPrompt
                }

                $command +=  "migrate"
            }
            4 { #basline
                Write-Host "`nCommand: BASELINE" -ForegroundColor DarkGray
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkGray
                Write-Host "Baselines an existing database, excluding all migrations up to and including baselineVersion." -ForegroundColor DarkGray

                $command = DisplayBaselineVersionPrompt
                $command += DisplayBaselineDescriptionPrompt
                $command +=  "baseline"

            }
            5 { #clean

                Write-Host "`nCommand: CLEAN" -ForegroundColor DarkGray
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkGray
                Write-Host "nDrops all objects (tables, views, procedures, triggers, ...) in the configured schema." -ForegroundColor DarkGray

                #if clean disabled is set in the setting prevent the action from being set
                If ($appEnv.name -eq "LIVE" -or $appEnv.allowClean -eq "false") {
                    Write-Host "`nERROR: Unable to execute the clean command as it is DISABLED for the" $appEnv.name "environment." -ForegroundColor Red
                    Write-Host "`ERROR: To enable the clean command please update the allowClean property within the configuration file ($configFile)" -ForegroundColor Red
                    continue OuterLoop
                }

                $cleanDisabled = (![System.Convert]::ToBoolean($appEnv.allowClean)).ToString().ToLower()
                $command = " -cleanDisabled=`"$cleanDisabled`" "
                $command += "clean"

                #blank the paramterrs that are not require for this command
                $locations = [string]::Empty
            }
            6 {
                $command =  "-?"
                #blank the paramterrs that are not require for this command
                $url,$user,$password,$locations = [string]::Empty
            }
            7 {
                Write-Host "`nReturning to environment selection" -ForegroundColor Cyan
                break OuterLoop
            }
        }

        if ([System.Convert]::ToBoolean($config.app.global.debugEnabled)){
            $command += " -X"
        }

        #the environment details which will be used when executing the command
        $flyEnvDetails = $url + $user + $password + $locations

        #mask the user details for the confirmation and logging of the output to the console
        $flyEnvDetailsMasked = $url + "  -user=****  -password=******** " + $locations

        #mask the envrionment details when logging of the output to the console
        $flyEnvDetailsMasked = [string]::Empty

        if ($command -ne "-?"){
            $flyEnvDetailsMasked = $url + "  -user=****  -password=******** " + $locations
        }

        Write-Host "`nAbout to execute command: " -ForegroundColor Cyan -NoNewline
        Write-Host "flyway $flyEnvDetailsMasked $command" -ForegroundColor Green

        $message = "`nDo you want to proceed?"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Executes the command"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Returns to the Flyway Database Command Menu"
        $result = $host.ui.PromptForChoice('', $message, @($yes, $no), 0)

        switch ($result){
            0 {
                Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan
                Write-Host "Executing command: flyway $flyEnvDetailsMasked $command" -ForegroundColor Cyan
                Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

                & { invoke-expression " & $cmdPath $flyEnvDetails $command" }

                Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor Cyan

            }
        }

    } while ($false -ne $true)
}


Clear-Host
$Title = 'Flyway Database Migration Powershell CLI'
Write-Host "============================================================================================================`n" -ForegroundColor Yellow
Write-Host "================================= $Title =================================`n" -ForegroundColor Yellow
Write-Host "============================================================================================================" -ForegroundColor Yellow

$config = LoadEnvironmentDetails
ShowTopMenu
