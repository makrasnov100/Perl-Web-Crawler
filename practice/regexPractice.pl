open(INFILE, "<test.txt");
@lines = <INFILE>;
close(INFILE)

for $line (@lines) {
   chomp $line;
   if ($line =~ /hello/) {
      print "match : $line";
   }
   else {
      print "nomatch : $line";
   }
   print "\n";
}