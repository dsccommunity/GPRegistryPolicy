#region HEADER
$script:dscModuleName = 'GPRegistryPolicyDsc'
$script:dscResourceName = 'MSFT_RegistryPolicyFile'

function Invoke-TestSetup
{
    try
    {
        Import-Module -Name DscResource.Test -Force
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Unit'
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

try
{
    InModuleScope $script:dscResourceName {
        $mockFolderObject = $null

        Describe 'MSFT_RegistryPolicyFile\Get-TargetResource' -Tag 'Get' {
            BeforeAll {
                $defaultParameters = @{
                    Key        = 'SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                    ValueName  = 'SMB1'
                    TargetType = 'ComputerConfiguration'
                }
            }

            BeforeEach {
                $getTargetResourceParameters = $defaultParameters.Clone()
            }

            Context 'When the configuration is absent' {
                BeforeEach {
                    Mock -CommandName Get-RegistryPolicyFilePath -MockWith {
                        'C:\Windows\System32\GroupPolicy\Machine\registry.pol'
                    }

                    Mock -CommandName Test-Path -MockWith {
                        $true
                    }

                    $registryPolicyParameters = @{
                        Key       = 'SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                        ValueName = 'SMB1NotPresent'
                        ValueType = 'REG_DWORD'
                        ValueData = 1
                    }
                    $mockReadPolicyFile = New-GPRegistryPolicy @registryPolicyParameters

                    Mock -CommandName Read-GPRegistryPolicyFile -MockWith {
                        $mockReadPolicyFile
                    }
                }

                It 'Should return the state as absent' {
                    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters
                    $getTargetResourceResult.Ensure | Should -Be 'Absent'

                    Assert-MockCalled Test-Path -Exactly -Times 1 -Scope It
                    Assert-MockCalled Get-RegistryPolicyFilePath -Exactly -Times 1 -Scope It
                    Assert-MockCalled Read-GPRegistryPolicyFile -Exactly -Times 1 -Scope It
                }

                It 'Should return the correct values to reflect key is absent' {
                    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters

                    $getTargetResourceResult.Key | Should -Be $getTargetResourceParameters.Key
                    $getTargetResourceResult.ValueName | Should -Be $getTargetResourceParameters.ValueName
                    $getTargetResourceResult.TargetType | Should -Be $getTargetResourceParameters.TargetType
                    $getTargetResourceResult.Path | Should -Be 'C:\Windows\System32\GroupPolicy\Machine\registry.pol'
                    $getTargetResourceResult.ValueData | Should -BeNullOrEmpty
                    $getTargetResourceResult.ValueType | Should -BeNullOrEmpty
                }
            }

            Context 'When the configuration is present' {
                BeforeAll {
                    $polPath = 'C:\Windows\System32\GroupPolicyUsers\S-1-5-21-3318452954-581252911-2334442305-1001\User\Registry.pol'
                    $defaultParameters = @{
                        Key        = 'SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                        ValueName  = 'SMB1'
                        TargetType = 'Account'
                        AccountName = 'User1'
                    }
                }

                BeforeEach {
                    Mock -CommandName Get-RegistryPolicyFilePath -MockWith {
                        $polPath
                    }

                    Mock -CommandName Test-Path -MockWith {
                        $true
                    }

                    $registryPolicyParameters = @{
                        Key       = 'SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                        ValueName = 'SMB1'
                        ValueType = 'REG_DWORD'
                        ValueData = 1
                    }
                    $mockReadPolicyFile = New-GPRegistryPolicy @registryPolicyParameters
                    Mock -CommandName Read-GPRegistryPolicyFile -MockWith {
                        $mockReadPolicyFile
                    }

                    Mock -CommandName ConvertTo-NTAccountName -MockWith {
                        'User1'
                    }
                }

                It 'Should return the state as present' {
                    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters
                    $getTargetResourceResult.Ensure | Should -Be 'Present'

                    Assert-MockCalled Test-Path -Exactly -Times 1 -Scope It
                    Assert-MockCalled Get-RegistryPolicyFilePath -Exactly -Times 1 -Scope It
                    Assert-MockCalled Read-GPRegistryPolicyFile -Exactly -Times 1 -Scope It
                    Assert-MockCalled ConvertTo-NTAccountName -Exactly -Times 1 -Scope It
                }

                It 'Should return the same values as passed as parameters' {
                    $getTargetResourceResult = Get-TargetResource @getTargetResourceParameters
                    $getTargetResourceResult.Key | Should -Be $getTargetResourceParameters.Key
                    $getTargetResourceResult.ValueName | Should -Be $getTargetResourceParameters.ValueName
                    $getTargetResourceResult.ValueData | Should -Be 1
                    $getTargetResourceResult.AccountName | Should -Be 'User1'
                    $getTargetResourceResult.TargetType | Should -Be 'Account'
                    $getTargetResourceResult.Path | Should -Be $polPath
                }
            }
        }

        Describe 'MSFT_RegistryPolicyFile\Test-TargetResource' -Tag 'Test' {
            BeforeAll {
                $defaultParameters = @{
                    Key        = 'SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                    TargetType = 'ComputerConfiguration'
                    ValueName  = 'SMB1'
                    ValueData  = 1
                    ValueType  = 'DWORD'
                    Ensure     = 'Absent'
                }

                $getTargetResourceDefaultReadResults = @{
                    Path        = '"C:\Windows\System32\GroupPolicy\Machine\registry.pol"'
                    AccountName = 'Machine'
                }
            }

            BeforeEach {
                $testTargetResourceParameters = $defaultParameters.Clone()

            }

            Context 'When the system is in the desired state' {
                Context 'When the configuration are absent' {
                    BeforeAll {
                        Mock -CommandName Get-TargetResource -MockWith {
                            $getTargetResourceResults
                        }
                    }

                    BeforeEach {
                        $testTargetResourceParameters['Ensure'] = 'Absent'
                        $getTargetResourceResults = $getTargetResourceDefaultReadResults + $testTargetResourceParameters

                    }

                    It 'Should return the $true' {
                        $testTargetResourceResult = Test-TargetResource @testTargetResourceParameters
                        $testTargetResourceResult | Should -Be $true

                        Assert-MockCalled Get-TargetResource -Exactly -Times 1 -Scope It
                    }
                }

                Context 'When the configuration are present' {
                    BeforeEach {
                        $testTargetResourceParameters['Ensure'] = 'Present'
                        $getTargetResourceResults = $getTargetResourceDefaultReadResults + $testTargetResourceParameters

                        Mock -CommandName Get-TargetResource -MockWith {
                            return $getTargetResourceResults
                        }
                    }

                    It 'Should return the $true' {
                        $testTargetResourceResult = Test-TargetResource @testTargetResourceParameters
                        $testTargetResourceResult | Should -Be $true

                        Assert-MockCalled Get-TargetResource -Exactly -Times 1 -Scope It
                    }
                }
            }

            Context 'When the system is not in the desired state' {
                Context 'When the configuration should be absent' {
                    BeforeEach {
                        $testTargetResourceParameters['Ensure'] = 'Absent'
                        $getTargetResourceResults = $getTargetResourceDefaultReadResults + $testTargetResourceParameters
                        $getTargetResourceResults['Ensure'] = 'Present'
                    }

                    It 'Should return the $false' {
                        Mock -CommandName Get-TargetResource -MockWith {
                            $getTargetResourceResults
                        }

                        $testTargetResourceResult = Test-TargetResource @testTargetResourceParameters
                        $testTargetResourceResult | Should -Be $false
                    }
                }

                Context 'When the configuration should be present' {
                    BeforeEach {
                        $testTargetResourceParameters['Ensure'] = 'Present'
                        $getTargetResourceResults = $getTargetResourceDefaultReadResults + $testTargetResourceParameters
                        $getTargetResourceResults['ValueData'] = 0
                    }

                    It 'Should return the $false' {
                        Mock -CommandName Get-TargetResource -MockWith {
                            $getTargetResourceResults
                        }

                        $testTargetResourceResult = Test-TargetResource @testTargetResourceParameters
                        $testTargetResourceResult | Should -Be $false
                    }
                }
            }
        }

        Describe 'MSFT_RegistryPolicyFile\Set-TargetResource' -Tag 'Set' {
            BeforeAll {
                $defaultParameters = @{
                    Key        = 'SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                    TargetType = 'ComputerConfiguration'
                    ValueName  = 'SMB1'
                    ValueData  = 1
                    ValueType  = 'DWORD'
                    Ensure     = 'Present'
                }

                Mock -CommandName New-GPRegistryPolicy -ParameterFilter {
                    $Key -eq $setTargsetTargetResourceParameters.Key -and
                    $ValueName -eq $setTargsetTargetResourceParameters.ValueName -and
                    $ValueData -eq $setTargsetTargetResourceParameters.ValueData -and
                    $ValueType -eq 'REG_DWORD'
                }

                Mock -CommandName New-GPRegistryPolicyFile -ParameterFilter {
                    $Path -eq $polFilePath
                }

                Mock -CommandName Set-GPRegistryPolicyFileEntry

                $polFilePath = "C:\Windows\System32\GroupPolicy\Machine\registry.pol"
                Mock -CommandName Set-RefreshRegistryKey
            }

            BeforeEach {
                $setTargetResourceParameters = $defaultParameters.Clone()
            }

            Context 'When the configuration should be absent' {
                BeforeAll {
                    Mock -CommandName Get-TargetResource -MockWith {
                        return @{
                            Ensure = 'Present'
                        }
                    }

                    Mock -CommandName Remove-GPRegistryPolicyFileEntry

                    Mock -CommandName Get-RegistryPolicyFilePath -ParameterFilter {
                        $TargetType -eq $setTargetResourceParameters.TargetType -and
                        $null -eq $AccountName
                    }
                }

                BeforeEach {
                    $setTargetResourceParameters['Ensure'] = 'Absent'
                }

                It 'Should call the correct mocks' {
                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Remove-GPRegistryPolicyFileEntry -Exactly -Times 1 -Scope 'It'
                    Assert-MockCalled -CommandName Set-RefreshRegistryKey -Exactly -Times 1 -Scope 'It'
                }
            }

            Context 'When the configuration should be present' {
                BeforeAll {
                    Mock -CommandName Get-TargetResource -MockWith {
                        return @{
                            Ensure = 'Absent'
                        }
                    }

                    Mock -CommandName Test-Path -MockWith {$false}
                }

                BeforeEach {
                    $setTargetResourceParameters['Ensure'] = 'Present'
                }

                It 'Should call the correct mocks' {
                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName New-GPRegistryPolicyFile -Exactly -Times 1 -Scope 'It'
                    Assert-MockCalled -CommandName Set-GPRegistryPolicyFileEntry -Exactly -Times 1 -Scope 'It'
                    Assert-MockCalled -CommandName Set-RefreshRegistryKey -Exactly -Times 1 -Scope 'It'
                    Assert-MockCalled -CommandName New-GPRegistryPolicyFile -Exactly -Times 1 -Scope 'It'
                }
            }

            Context 'When the configuration is present but has the wrong properties' {
                BeforeAll {
                    Mock -CommandName Get-TargetResource -MockWith {
                        return @{
                            Ensure = 'Present'
                        }
                    }

                    Mock -CommandName Test-Path -MockWith {$true}
                }

                It 'Should call the correct mocks' {
                    { Set-TargetResource @setTargetResourceParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName New-GPRegistryPolicyFile -Exactly -Times 0 -Scope 'It'
                    Assert-MockCalled -CommandName Set-GPRegistryPolicyFileEntry -Exactly -Times 1 -Scope 'It'
                    Assert-MockCalled -CommandName Set-RefreshRegistryKey -Exactly -Times 1 -Scope 'It'
                }
            }
        }

        Describe 'MSFT_RegistryPolicyFile\Get-RegistryPolicyFilePath' -Tag 'Helper' {
            BeforeAll {
                Mock -CommandName ConvertTo-SecurityIdentifier -ParameterFilter {$AccountName -ne 'administrators'}

                $filePathMap  = @{
                    ComputerConfiguration = 'System32\GroupPolicy\Machine\registry.pol'
                    UserConfiguration     = 'System32\GroupPolicy\User\registry.pol'
                    Administrators = 'System32\GroupPolicyUsers\S-1-5-32-544\User\registry.pol'
                    NonAdministrators = 'System32\GroupPolicyUsers\S-1-5-32-545\User\registry.pol'
                    Account = 'System32\GroupPolicyUsers\S-1-5-32-544\User\registry.pol'
                }

                $testCases = @(
                    @{TargetType = 'ComputerConfiguration'}
                    @{TargetType = 'UserConfiguration'}
                    @{TargetType = 'Administrators'}
                    @{TargetType = 'NonAdministrators'}
                    @{TargetType = 'Account';AccountName = 'administrators'}
                )
            }

            Context 'Asserting correct path' {
                It 'Should return the correct path for <TargetType>' -TestCases $testCases {
                    param ($TargetType, $AccountName)
                    $result = Get-RegistryPolicyFilePath -TargetType $TargetType -AccountName $AccountName
                    $desiredResult = Join-Path -Path $env:SystemRoot -ChildPath $filePathMap[$TargetType]

                    $result | Should -Be $desiredResult
                }
            }

            Context 'TargetType is Account and AccountName is null' {
                It 'Should throw' {
                    {Get-RegistryPolicyFilePath -TargetType 'Account' -AccountName $null} | Should -Throw
                }
            }
        }

        Describe 'MSFT_RegistryPolicyFile\ConvertTo-SecurityIdentifer' -Tag 'Helper' {
            Context 'Assert correct SID is returned' {
                It 'Should return the correct SID' {
                    $result = ConvertTo-SecurityIdentifier -AccountName Administrators
                    $result | Should -Be 'S-1-5-32-544'
                }
            }
        }

        Describe 'MSFT_RegistryPolicyFile\ConvertTo-NTAccountName' -Tag 'Helper' {
            Context 'Assert correct NTAccountName is returned' {
                It 'Return the correct NTAccountName' {
                    $result = ConvertTo-NTAccountName -SecurityIdentifier 'S-1-5-32-544'
                    $result | Should -Be 'BUILTIN\Administrators'
                }
            }
        }

        Describe 'MSFT_RegistryPolicyFile\Set-RefreshRegistryKey' -Tag 'SetRefreshRegistryKey' {
            Context 'When setting a registry key to indicate a group policy refresh is needed' {
                BeforeAll {
                    $newItemParameteres = @{
                        Path         = 'HKLM:\SOFTWARE\Microsoft\GPRegistryPolicy'
                        PropertyName = 'RefreshRequired'
                        Value = 1
                    }
                    Mock -CommandName New-Item
                    Mock -CommandName New-ItemProperty
                }
                It 'Should set the proper registry key' {
                    {Set-RefreshRegistryKey @newItemParameteres} | Should -Not -Throw

                    Assert-MockCalled -CommandName New-Item -ParameterFilter {
                        $Path -eq $newItemParameteres.Path
                    } -Times 1 -Exactly

                    Assert-MockCalled -CommandName New-ItemProperty -ParameterFilter {
                        $Path -eq $newItemParameteres.Path -and
                        $Name -eq $newItemParameteres.PropertyName -and
                        $Value -eq $newItemParameteres.Value
                    } -Times 1 -Exactly
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}

