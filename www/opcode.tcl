#
# Run this Tcl script to generate the sqlite.html file.
#
set rcsid {$Id: opcode.tcl,v 1.14 2004/10/10 17:24:55 drh Exp $}
source common.tcl
header {SQLite Virtual Machine Opcodes}
puts {
<h2>SQLite Virtual Machine Opcodes</h2>
}

set fd [open [lindex $argv 0] r]
set file [read $fd [file size [lindex $argv 0]]]
close $fd
set current_op {}
foreach line [split $file \n] {
  set line [string trim $line]
  if {[string index $line 1]!="*"} {
    set current_op {}
    continue
  }
  if {[regexp {^/\* Opcode: } $line]} {
    set current_op [lindex $line 2]
    set Opcode($current_op:args) [lrange $line 3 end]
    lappend OpcodeList $current_op
    continue
  }
  if {$current_op==""} continue
  if {[regexp {^\*/} $line]} {
    set current_op {}
    continue
  }
  set line [string trim [string range $line 3 end]]
  if {$line==""} {
    append Opcode($current_op:text) \n<p>
  } else {
    append Opcode($current_op:text) \n$line
  }
}
unset file

puts {
<h3>Introduction</h3>

<p>In order to execute an SQL statement, the SQLite library first parses
the SQL, analyzes the statement, then generates a short program to execute
the statement.  The program is generated for a "virtual machine" implemented
by the SQLite library.  This document describes the operation of that
virtual machine.</p>

<p>This document is intended as a reference, not a tutorial.
A separate <a href="vdbe.html">Virtual Machine Tutorial</a> is 
available.  If you are looking for a narrative description
of how the virtual machine works, you should read the tutorial
and not this document.  Once you have a basic idea of what the
virtual machine does, you can refer back to this document for
the details on a particular opcode.
Unfortunately, the virtual machine tutorial was written for
SQLite version 1.0.  There are substantial changes in the virtual
machine for version 2.0 and the document has not been updated.
</p>

<p>The source code to the virtual machine is in the <b>vdbe.c</b> source
file.  All of the opcode definitions further down in this document are
contained in comments in the source file.  In fact, the opcode table
in this document
was generated by scanning the <b>vdbe.c</b> source file 
and extracting the necessary information from comments.  So the 
source code comments are really the canonical source of information
about the virtual machine.  When in doubt, refer to the source code.</p>

<p>Each instruction in the virtual machine consists of an opcode and
up to three operands named P1, P2 and P3.  P1 may be an arbitrary
integer.  P2 must be a non-negative integer.  P2 is always the
jump destination in any operation that might cause a jump.
P3 is a null-terminated
string or NULL.  Some operators use all three operands.  Some use
one or two.  Some operators use none of the operands.<p>

<p>The virtual machine begins execution on instruction number 0.
Execution continues until (1) a Halt instruction is seen, or 
(2) the program counter becomes one greater than the address of
last instruction, or (3) there is an execution error.
When the virtual machine halts, all memory
that it allocated is released and all database cursors it may
have had open are closed.  If the execution stopped due to an
error, any pending transactions are terminated and changes made
to the database are rolled back.</p>

<p>The virtual machine also contains an operand stack of unlimited
depth.  Many of the opcodes use operands from the stack.  See the
individual opcode descriptions for details.</p>

<p>The virtual machine can have zero or more cursors.  Each cursor
is a pointer into a single table or index within the database.
There can be multiple cursors pointing at the same index or table.
All cursors operate independently, even cursors pointing to the same
indices or tables.
The only way for the virtual machine to interact with a database
file is through a cursor.
Instructions in the virtual
machine can create a new cursor (Open), read data from a cursor
(Column), advance the cursor to the next entry in the table
(Next) or index (NextIdx), and many other operations.
All cursors are automatically
closed when the virtual machine terminates.</p>

<p>The virtual machine contains an arbitrary number of fixed memory
locations with addresses beginning at zero and growing upward.
Each memory location can hold an arbitrary string.  The memory
cells are typically used to hold the result of a scalar SELECT
that is part of a larger expression.</p>

<p>The virtual machine contains a single sorter.
The sorter is able to accumulate records, sort those records,
then play the records back in sorted order.  The sorter is used
to implement the ORDER BY clause of a SELECT statement.</p>

<p>The virtual machine contains a single "List".
The list stores a list of integers.  The list is used to hold the
rowids for records of a database table that needs to be modified.
The WHERE clause of an UPDATE or DELETE statement scans through
the table and writes the rowid of every record to be modified
into the list.  Then the list is played back and the table is modified
in a separate step.</p>

<p>The virtual machine can contain an arbitrary number of "Sets".
Each set holds an arbitrary number of strings.  Sets are used to
implement the IN operator with a constant right-hand side.</p>

<p>The virtual machine can open a single external file for reading.
This external read file is used to implement the COPY command.</p>

<p>Finally, the virtual machine can have a single set of aggregators.
An aggregator is a device used to implement the GROUP BY clause
of a SELECT.  An aggregator has one or more slots that can hold
values being extracted by the select.  The number of slots is the
same for all aggregators and is defined by the AggReset operation.
At any point in time a single aggregator is current or "has focus".
There are operations to read or write to memory slots of the aggregator
in focus.  There are also operations to change the focus aggregator
and to scan through all aggregators.</p>

<h3>Viewing Programs Generated By SQLite</h3>

<p>Every SQL statement that SQLite interprets results in a program
for the virtual machine.  But if you precede the SQL statement with
the keyword "EXPLAIN" the virtual machine will not execute the
program.  Instead, the instructions of the program will be returned
like a query result.  This feature is useful for debugging and
for learning how the virtual machine operates.</p>

<p>You can use the <b>sqlite</b> command-line tool to see the
instructions generated by an SQL statement.  The following is
an example:</p>}

proc Code {body} {
  puts {<blockquote><tt>}
  regsub -all {&} [string trim $body] {\&amp;} body
  regsub -all {>} $body {\&gt;} body
  regsub -all {<} $body {\&lt;} body
  regsub -all {\(\(\(} $body {<b>} body
  regsub -all {\)\)\)} $body {</b>} body
  regsub -all { } $body {\&nbsp;} body
  regsub -all \n $body <br>\n body
  puts $body
  puts {</tt></blockquote>}
}

Code {
$ (((sqlite ex1)))
sqlite> (((.explain)))
sqlite> (((explain delete from tbl1 where two<20;)))
addr  opcode        p1     p2     p3                                      
----  ------------  -----  -----  ----------------------------------------
0     Transaction   0      0                                              
1     VerifyCookie  219    0                                              
2     ListOpen      0      0                                              
3     Open          0      3      tbl1                                    
4     Rewind        0      0                                              
5     Next          0      12                                             
6     Column        0      1                                              
7     Integer       20     0                                              
8     Ge            0      5                                              
9     Recno         0      0                                              
10    ListWrite     0      0                                              
11    Goto          0      5                                              
12    Close         0      0                                              
13    ListRewind    0      0                                              
14    OpenWrite     0      3                                              
15    ListRead      0      19                                             
16    MoveTo        0      0                                              
17    Delete        0      0                                              
18    Goto          0      15                                             
19    ListClose     0      0                                              
20    Commit        0      0                                              
}

puts {
<p>All you have to do is add the "EXPLAIN" keyword to the front of the
SQL statement.  But if you use the ".explain" command to <b>sqlite</b>
first, it will set up the output mode to make the program more easily
viewable.</p>

<p>If <b>sqlite</b> has been compiled without the "-DNDEBUG=1" option
(that is, with the NDEBUG preprocessor macro not defined) then you
can put the SQLite virtual machine in a mode where it will trace its
execution by writing messages to standard output.  The non-standard
SQL "PRAGMA" comments can be used to turn tracing on and off.  To
turn tracing on, enter:
</p>

<blockquote><pre>
PRAGMA vdbe_trace=on;
</pre></blockquote>

<p>
You can turn tracing back off by entering a similar statement but
changing the value "on" to "off".</p>

<h3>The Opcodes</h3>
}

puts "<p>There are currently [llength $OpcodeList] opcodes defined by
the virtual machine."
puts {All currently defined opcodes are described in the table below.
This table was generated automatically by scanning the source code
from the file <b>vdbe.c</b>.</p>}

puts {
<p><table cellspacing="1" border="1" cellpadding="10">
<tr><th>Opcode&nbsp;Name</th><th>Description</th></tr>}
foreach op [lsort -dictionary $OpcodeList] {
  puts {<tr><td valign="top" align="center">}
  puts "<a name=\"$op\">$op</a>"
  puts "<td>[string trim $Opcode($op:text)]</td></tr>"
}
puts {</table></p>}
footer $rcsid
