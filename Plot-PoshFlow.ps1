Import-Module PSGraph
Import-Module DependencyObject

#this is for my dev station, ignore|remove
if ($(get-item Env:\COMPUTERNAME).value -eq 'SRVUTIL1') {
    $PSDefaultParameterValues = @{'Export-PSGraph:GraphVizPath' = 'E:\Shares\public\progs\graphviz\bin\dot.exe'}   
    pushd E:\Shares\public\Scripts\Plot-PoshFlow
    }

#functions to parse AST

 
function PParse-AstStatement {
    param ($Statement,$Parent)
    if ($Statement) {
    $DepObj = $Parent
        'Statement count: ' + $statement.count | Write-Debug
        foreach ($i in 0..($statement.count -1)) {
        
        $StatementType = ($Statement[$i].GetType()).Name
        $StatementType | Write-Debug
        $ShouldParseDefault = $true

            Switch ($StatementType) {
                'IfStatementAst' {
                    $DepObj = PParse-AstIfStatementAst $Statement[$i]  $DepObj
                    $ShouldParseDefault = $false
                    }
                'TryStatementAst' {
                    $DepObj = PParse-AstTryStatementAst $Statement[$i]  $DepObj
                    $ShouldParseDefault = $false
                    }
                'SwitchStatementAst' {
                    $DepObj = PParse-AstSwitchStatementAst $Statement[$i]  $DepObj
                    $ShouldParseDefault = $false
                    }

                default {
                    if ($ShouldParseDefault) {
                        if ($DepObj.Type -eq 'default') {
                            $DepObj.Name += [Environment]::NewLine
                            $DepObj.Name += ( $Statement[$i].Extent.Text )
                            }
                            else {
                            $DepObj = New-DependencyObject ( $Statement[$i].Extent.Text) -DependOn $DepObj -CreateVariable -Type default
                            }
                        }
                    }
                }# End Switch StatementType
            
            }#end %
        $DepObj
        }#end if 
    }#end Function Parse-AstStatement


function PParse-AstTryStatementAst {param ($Statement,$Parent) 

    $TryBlockStart = New-DependencyObject -name '' -DependOn $parent -Type TryBlock -CreateVariable
    $TryBlockBody = PParse-AstStatement -Statement $Statement.body.Statements -Parent $TryBlockStart
    
    $catch = New-DependencyObject -Name Catch -DependOn $TryBlockStart -Type CatchBlock -CreateVariable 
    if ($statement.CatchClauses.Body.Statements) {
        $catch = PParse-AstStatement -Statement $statement.CatchClauses.Body.Statements -Parent $catch
        'cc-b-s' | Write-Debug 
        }
        else {
        'cc-b-s NEG' | Write-Debug 
        $catch = New-DependencyObject -name $statement.CatchClauses.extent.text -DependOn $catch -Type CatchBlockEnd -CreateVariable
        }
    
    'AstTryStatementAst Finally' | Write-Debug

    $TryBlockFinally = New-DependencyObject -name $statement.finally.Extent.Text -DependOn $catch -Type FinallyBlock -CreateVariable
    $TryBlockFinally.adddependoN($TryBlockBody)
    $last = New-DependencyObject -name TryBlockEnd -DependOn $TryBlockFinally -Type TryBlockEnd -CreateVariable
     
    $last
    }#End func

function PParse-AstIfStatementAst {param ($Statement,$Parent)
    
    $ClauseRoot = New-DependencyObject -name 'if' -DependOn $parent -Type IfStatementAstStart -CreateVariable
    $DepObj = $ClauseRoot
    
    $IfStatementEndDO = New-DependencyObject 'fi' -CreateVariable -Type IfStatementAstEnd  #-DependOn $ClauseRoot 
    foreach ($i in 0..($statement.Count - 1)) {
        
        $PSCmdlet.MyInvocation.MyCommand.Name + ': ' + 'Statement ' + $i | Write-Debug
        
  
        $prevClause = $ClauseRoot
        foreach ($Clause in $Statement[$i].Clauses) {
            $ClauseStart = New-DependencyObject -DependOn $prevClause -CreateVariable -Type 'IfClause'
            $ClauseStatement = New-DependencyObject ($Clause.Item1.Extent.Text) -DependOn $ClauseStart -CreateVariable -Type 'IfClauseStatement'
            $ClauseEnd =  New-DependencyObject 'IfEnd' -DependOn  $ClauseStart -CreateVariable -Type 'FlowReturn'
            if($DepObj.type -eq 'ifClause') {
                #$prevClause.addDependOn($DepObj)
                }
            $DepObj = $ClauseStatement
             
            foreach ($SubClause in $Clause.Item2.Statements) {
                $DepObj =  PParse-AstStatement $SubClause $DepObj    
                }
            
            $ClauseEnd.AddDependOn($DepObj)
            #$IfStatementEndDO.addDependOn($DepObj )
            $DepObj =  $ClauseEnd
            $prevClause = $ClauseEnd
            }
        
         #$DepObj.addDependOn($prevClause)
        foreach ($Clause in $Statement[$i].ElseClause) {
            
            $prevClause =  New-DependencyObject 'start' -DependOn $prevClause -CreateVariable -Type 'ElseClause'
            
            #$prevClause.addDependOn($DepObj)
            $DepObj = $prevClause
            foreach ($SubClause in $Clause.Statements) {
                $DepObj =  PParse-AstStatement $SubClause $DepObj    
                }
            $DepObj =  New-DependencyObject 'ElseEnd' -DependOn $DepObj,$prevClause -CreateVariable -Type 'FlowReturn'
            }
        
        }#End %
         
    $IfStatementEndDO.addDependOn($DepObj)
    #$IfStatementEndDO.addDependOn($prevClause)
    $IfStatementEndDO
     
    }
      


function PParse-AstSwitchStatementAst {param ($Statement,$Parent) 
    
    $SwitchStart = New-DependencyObject -name 'Switch' -DependOn $parent -Type SwitchStatementAstStart -CreateVariable
    $DepObj = $SwitchStart
    
    $SwitchEnd = New-DependencyObject 'Switch' -CreateVariable -Type SwitchStatementAstEnd  -DependOn $SwitchStart 
   
    $swCondition = $Statement.Condition.PipelineElements[0].parent.extent.text
    $DepObj = New-DependencyObject $swCondition -Type SwitchCondition -DependOn $DepObj -CreateVariable
    foreach ($Clause in $Statement.Clauses) {
        $ClauseObj = New-DependencyObject $Clause.Item1.Extent.Text -Type SwitchClause -DependOn $DepObj -CreateVariable
        $DepObj = $ClauseObj  
        foreach ($SubClause in $Clause.Item2.Statements) {
            $DepObj =  PParse-AstStatement $SubClause $DepObj    
            }
        $DepObj = $ClauseObj  
            #$Clause.Item2.Statements SwitchStatement
        }


    
    $SwitchEnd.addDependOn($DepObj)
    $SwitchEnd
    }



#cleanup if running interactive
Remove-DOVariable

#Assign $functionName to the name of function to plot

$FunctionName = 'edge'

$gcm = Get-Command $FunctionName | select *
$root = New-DependencyObject $FunctionName -CreateVariable -Type FunctionStart

#this is leftovers, should be cleaned
$DepObj = $root
$root = $null

#this is blocks of function to process, I didn't wrote automagik to select proper blocks.

$BlockList = @('beginblock','processblock','EndBlock')
foreach ($BlockName in $BlockList) {
    $Statement = $gcm.ScriptBlock.Ast.Body.$BlockName.Statements 

    $DepObj = New-DependencyObject -name $BlockName -DependOn $DepObj -Type BlockStart -CreateVariable
    foreach ($i in 0..($Statement.count -1)) {
        $DepObj = PParse-AstStatement $Statement[$i]  $DepObj
        }
    $DepObj = New-DependencyObject $BlockName -DependOn $DepObj -CreateVariable -Type BlockEnd 
    }

#now really starting to plot

function get-RankNodes {param ($co) 
    @( $co.guid, ($COs | ? {$_.dependon -contains $co.guid }  | % {$_.guid}) )
    }
    
function get-DOByGUID {param ($guid)
    $COs | ? {$_.guid -eq $guid}
    }

$COs = Get-DOVariable 
$UsedTypes = $cos | select type -Unique

    $Graph = graph {
    inline rankdir=TB
    #inline ranksep=1
 
   foreach ($co in $COs) {
        [string]$label = $( if ($co.type) {'['+$co.type+']\n'} ) + $co.name
        
        $color = ''
        $shape = 'box'
        $margin = '0.11,0.055'
        switch ($co.type) {
 
            'ElseClause' {$shape='diamond';$margin="0.5,0.05"}
            'IfClause' {$shape='diamond'}            
            'IfStatementAstStart' {$shape='point';$color='yellow'
                }
            'IfStatementAstEnd' {$shape='point';$color='green'}
            'FlowReturn' {$shape='point';$color='red'}
            'blockstart' {$shape='invtriangle'}
            'blockend' {$shape='triangle'}
            'default' {$shape='note'}
            'SwitchCondition' {
                
                $cluster = $co | Walk-DependencyObject -type SwitchClause -depth 10 
                
                }
            } #end switch 
         
       
        if ($cluster) {
            SubGraph  {
                foreach ($node in $cluster) {
                     
                    if ($node.subtype -notlike '*_Drawn*') {
                        $label = $( if ($node.type) {'['+$node.type+']\n'} ) + $node.name
                        node -Name $node.guid -Attributes @{label=$Label;shape=$shape;;color=$nodelor;margin=$margin} 
                        $node.subtype = $node.subtype += '_Drawn'
                        }
  
                    }
                }

            $node = $null
            $cluster = $null

            }
            

        if ($co.subtype -notlike '*_Drawn*') {
            node -Name $CO.guid -Attributes @{label=$Label;shape=$shape;;color=$color;margin=$margin} 
            $co.subtype = $co.subtype += '_Drawn'
            }


        foreach ($guid in $CO.DependedBy) {
            $dependency = get-DOByGUID $guid
            #write-host $guid -BackgroundColor Red
            if     (($dependency.type -eq 'FlowReturn') -and ('IfClause','ElseClause' -notcontains $co.type)) {
                edge -From $co.guid -to $guid  -Attributes @{tailport='s';headport='e'}
                }
            elseif (($co.type -eq 'FlowReturn') -and ('IfClause','ElseClause' -contains $dependency.type)) {
                edge -From $co.guid -to $guid  -Attributes @{color='blue'}
                }
            elseif (($dependency.type -eq 'FlowReturn') -and ($co.type -eq 'IfClause')) {
                edge -From $co.guid -to $guid  -Attributes @{color='blue'}
                }
            elseif (($dependency.type -eq 'FlowReturn') -and ($co.type -eq 'ElseClause')) {
                edge -From $co.guid -to $guid  -Attributes @{color='blue'}
                }
            elseif (($dependency.type -eq 'IfStatementAstEnd') -and ($co.type -eq 'FlowReturn')) {
                edge -From $co.guid -to $guid  -Attributes @{color='blue'}
                }
            elseif (($dependency.type -eq 'IfClause') -and ($co.type -eq 'IfStatementAstStart')) {
                edge -From $co.guid -to $guid  -Attributes @{color='blue'}
                }
            elseif (($dependency.type -ne 'FlowReturn') -and ($co.type -eq 'IfClause')) {
                #edge -From $co.guid -to $guid  -Attributes @{tailport='e';headport='w';color='green'}
                 $str = '"'+$co.guid+'" -> "'+$guid+'" [color=green]'
                 $str
                 $str = $null
                 #rank $co.guid,$guid
                 $rank = '{ rank=same;  "' +$co.guid+ '"; "'+$guid+'"; } /* ($dependency.type -ne "FlowReturn") -and ($co.type -eq "IfClause") */'
                 $rank
                 $rank = $null
                 #write-host $str -BackgroundColor DarkCyan
               
                }
            elseif (($dependency.type -ne 'FlowReturn') -and ($co.type -eq 'elseClause')) {
                edge -From $co.guid -to $guid  -Attributes @{  color='red'}
                $rank = '{ rank=same;  "' +$co.guid+ '"; "'+$guid+'"; } /* ($dependency.type -ne "FlowReturn") -and ($co.type -eq "elseClause") */'
                $rank
                $rank = $null
                }
            else {
                edge -From $co.guid -to $guid
                }
            } # % dependency
 
        }
    
    
    foreach ($CO in $COs) {
        foreach ($Link in $CO.links) {
            edge -From $CO.guid -to $Link.guid -Attributes @{style='dotted';dir='forward';constraint='false'}

            }
        }
    
    
    }

Export-PSGraph -Source $graph -DestinationPath .\ParseAst.png -OutputFormat png  -LayoutEngine dot
Export-PSGraph -Source $graph -DestinationPath .\ParseAst.svg -OutputFormat svg  -LayoutEngine dot -ShowGraph
