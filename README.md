# Flyway PowerShell CLI 
The Flyway command-line tool is a standalone Flyway distribution that is primarily meant for users who wish to migrate 
their database from the command-line without having to integrate Flyway into their applications nor having to install a 
build tool. The tool itself is very powerful and useful however it does require familiarity with the configuration options and can 
require lengthy commands to be entered. For example:

```powershell
   flyway  -url=jdbc:h2:file:./sampledevdb  -user=SA  -password=  -locations=filesystem:./SQL/common,filesystem:./SQL/dev info

   flyway  -url=jdbc:h2:file:./sampledevdb  -user=SA  -password=  -locations=filesystem:./SQL/common,filesystem:./SQL/dev  -repeatableSqlMigrationPrefix="R"  -skipDefaultCallbacks="false"  -outOfOrder="false"  -validateOnMigrate="true"  -ignoreMissingMigrations="false"  -ignoreFutureMigrations="true"  -ignoreIgnoredMigrations="false" migrate
```

These commands are also ones that would generally be repeated when executing releases and with so many possible options 
it is possible to forget a location, a configuration property or even introduce an error due to a typo (or worse clean 
a production database!!). This is the main driver for the development of this tool

This is where the Flyway PowerShell CLI comes in to play which will help reduce the risk, improve efficiency and make 
the flyway tool more accessible.

The Flyway PowerShell CLI is simply a wrapper around the flyway command line which reads in configuration data for a single 
application covering all of its applicable environments and guides the users using an interactive prompt.

## Usage

```powershell
    flyway configFile [-debug]
```
Where configFile is the path to the specified JSON or XML application environment configuration file. See [Configuration File](#configuration-file)
for details on the format of the file.

Example:
```powershell
    flyway myApp.xml
    flyway myApp.json -debug
```

## Getting Started

To use the Flyway PowerShell CLI copy the `flyway.ps1` script into the root into the root directory of the flyway 
command line distribution so it sits along with the `flyway.cmd` batch script.

I also recommend that the directory where flyway command line scripts are located is added to the environment PATH 
variable.

The easiest way to get started and the see the benefits is to jump straight into the sample 'application' which uses 
a H2 File Database and contains 5 environments (dev, test, train, stage and production).

Checkout the project and navigate to the to the sample application:

```
    git clone https://github.com/cdavid15/flyway-ps-cli.git
    cd sample
```

Invoke the Flyway PowerShell CLI for the sample application

```powershell
    flyway myApp.json 
```

If you want to enable debugging it can be set through the Admin menu option for the session or by passing the `-debug` 
flag when invoking the CLI.

## Configuration File
The main benefit from the using the tool is that the configuration data is only ever specified once for each environment.

The configuration is defined in either xml or json format.

### XML:
Sample xml file:

```xml
    <app>
        <name>Sample Application</name>
        <global>
            <debugEnabled>false</debugEnabled>
            <schemaHistoryTable>flyway_schema_history</schemaHistoryTable>
            <installedBy>flyway migrations</installedBy>
        </global>
        <environments>
            <environment>
                <name>dev</name>
                <description>Development Database (H2)</description>
                <connection>
                    <url>jdbc:h2:file:./sampledevdb</url>
                    <user>SA</user>
                    <password></password>
                </connection>
                <locations>
                    <location>filesystem:./SQL/common</location>
                    <location>filesystem:./SQL/dev</location>
                </locations>
                <allowClean>true</allowClean>
            </environment>
        </environments>
    </app>
```

### JSON:
Sample JSON file:

```json
    {
        "app": {
            "name": "Sample Application",
            "global": {
                "debugEnabled": "false",
                "schemaHistoryTable": "flyway_schema_history",
                "installedBy": "flyway migrations"
            },
            "environments": {
                "environment": [
                    {
                        "name": "dev",
                        "description": "Development Database (H2)",
                        "connection": {
                            "url": "jdbc:h2:file:./sampledevdb",
                            "user": "SA"
                        },
                        "locations": {
                            "location": [
                                "filesystem:./SQL/common",
                                "filesystem:./SQL/dev"
                            ]
                        },
                        "allowClean": "true"
                    }
                ]
            }
        }
    }
```

## Compatibility
This has been tested against flyway community edition v5.0.7 and v5.1.1.

It does not currently cater for the commands and options available in the Pro and Enterprise editions such as undo, 
stream, batch, dry run etc.

## Contributing
Please feel free to contribute by submitting pull requests.
