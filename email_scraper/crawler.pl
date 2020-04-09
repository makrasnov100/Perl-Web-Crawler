
#INSTRUCTIONS
# Before first run - exucute the following in order in a terminal (w/o quotes):
# 'cpan App::cpanminus'
# 'cpanm URI::Find'
# 'cpanm Email::Find'

# DESCRIPTION:
# Author: Kostiantyn Makrasnov
# Date: 04/08/2020

# REFERENCES:
# 1) Loading file into an array: https://stackoverflow.com/questions/8963400/the-correct-way-to-read-a-data-file-into-an-array
# 2) Hashes in perl:             https://www.tutorialspoint.com/perl/perl_hashes.htm
# 3) Functions in perl:          https://www.tutorialspoint.com/perl/perl_subroutines.htm
# 4) Regex matches:              https://perldoc.perl.org/perlre.html
# 5) Appending to a file:        https://perlmaven.com/appending-to-files
# 6) substring match:            https://stackoverflow.com/questions/7011524/perl-if-string-contains-text
# 7) Working with URI::Find:     https://metacpan.org/pod/URI::Find
# 8) Nested sub routines:        https://stackoverflow.com/questions/10192228/nested-subroutines-and-scoping-in-perl

#PACKAGES
require HTTP::Request;
require LWP::UserAgent;
require Email::Find;
require URI::Find;

# for more debug messages
# use strict; use warnings;

# UTILITIES:
sub loadFile
{
    my $fileName = @_[0];
    my $retType = @_[1];

    open(my $file, '<', $fileName)
        or die "Can't open < $fileName: $!";
    my @fileLines = <$file>;
    close($file);

    if($retType eq "A")
    {
        return @fileLines;
    }
    else
    {
        my %entries;
        for(my $i = 0; $i < scalar(@fileLines); $i++)
        {
            if(!exists($entries{$fileLines[$i]}))
            {
                chomp($fileLines[$i]);
                $entries{@fileLines[$i]} = 1;
            }
        }

        return %entries;
    }
}

# appends all entries in a hash to a file
sub saveFile
{
    my $fileName = @_[0];
    my $contentRef = @_[1];
    my $targetContainerRef = @_[2];
    my @newContent = keys(%{$contentRef});

    #open the file to which need to append data
    open(my $file, '>>', $fileName)
        or die "Can't open >> $fileName: $!";

    foreach my $newEntry (@newContent)
    {
        if(!exists($$targetContainerRef{$newEntry}))
        {
            $$targetContainerRef{$newEntry} = 1;
            say $file "$newEntry";
        }
        else
        {
            print("$newEntry already in email list!\n");
        }
    }

    close($file);

    return ();
}

# writes all entries in a hash to a file
sub saveAll
{
    my $fileName = @_[0];
    my $contentRef = @_[1];
    my @content = keys(%{$contentRef});

    #open the file to which need to write data
    open(my $file, '>', $fileName)
        or die "Can't open > $fileName: $!";

    foreach my $entry (@content)
    {
        chomp($entry);
        say $file $entry;
    }

    close($file);
}

# used inorder to prevent the crawler from going to websites that were already visited
sub getDifference
{
    my $largerSetRef = @_[0];
    my $smallerSetRef = @_[1];
    my @smallerSet = keys(%{$smallerSetRef});
    my @largerSet = keys(%{$largerSetRef});
    my %originalHash = %$largerSetRef;

    my %difference;

    foreach my $entry (@largerSet)
    {
        $difference{$entry} = 1;
    }

    foreach my $entry (@smallerSet)
    {
        # print("Checking $entry for difference!\n");
        if(exists($originalHash{$entry}))
        {
            # print("Deleting $entry from difference!\n");
            delete $difference{$entry};
        }
    }

    if(%difference)
    {
        print("Some urls are good!\n");
    }
    else
    {
        print("No new urls to parse!\n");
    }

    return %difference;
}

sub getWebContent
{
    my $url = @_[0];
    my $req = HTTP::Request->new(GET => $url);
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);
    my @resp = split(/\n/, $response->content);
    return @resp;
}


sub proccessURLS
{
    my @urlList = keys(%{@_[0]});
    my %newUrls;
    my %newEmails;

    # go through all urls in original list and 
    foreach my $url (@urlList)
    {
        my @content = getWebContent($url);
        foreach my $line (@content) 
        {
            # USING PRE-BUILT PACKAGES WORKS WAY BETTER THAN REGEX BUT FOR ASSIGNMENT HERE THEY ARE
            # my @links = ($line =~ m/href=\"([\w\/\.\~\@\;\:\&]*)\"([.\n]*)/g);
            # my @emails = ($line =~ m/mailto\:(.*)"/g);

            my @emails;
            local *addEmail = sub
            {
                my ($addrObj, $email) = @_;
                push(@emails, $email);
            };
            my $emailFinder = Email::Find->new(\&addEmail);
            my $num_found - $emailFinder->find(\$line);
            if($num_found > 0)
            {
                print("Found $num_found emails.");
            }

            my @links;
            my $linkFinder = URI::Find->new(sub {
                my($uri) = shift;
                push(@links, $uri);
            });
            $linkFinder->find(\$line);

            foreach my $email (@emails) 
            {
                if(!exists($newEmail{$email}) && !exists($foundEmail{$email}))
                {
                    $newEmails{$email} = 1;
                }
            }

            foreach my $link (@links)
            {
                #add server name to link if not already present
                if(index($link, "http") == -1)
                {
                    $url =~ m/(https*:\/\/[\w*\.]*\w*)\/.*/;
                    $link = "$1$link";
                }

                if(!exists($newUrls{$link}) && !exists($foundUrl{$link}) && !exists($visitedUrl{$link}))
                {
                    $newUrls{$link} = 1;
                }
            }
            
            $visitedUrl{$url} = 1;
            delete $foundUrl{$url};
        }

        my $newEmailCount = 0;
        if(%newEmails)
        {
            $newEmailCount = scalar(keys(%newEmails));
            %newEmails = saveFile("data/found_emails.txt", \%newEmails, \%foundEmail);
        }

        my $newLinkCount = 0;
        if(%newUrls)
        {
            $newLinkCount = scalar(keys(%newUrls));
        }
        
        #Show status
        chomp($url);
        print("$countUrlParsed. URL Parse Complete - Currently $newLinkCount Queued Links and Found $newEmailCount New Emails | Website: $url\n");

        # Counts of complete URL to save state every once in a while
        if($countUrlParsed % $visitedSaveInterval == 0)
        {
            saveAll("data/visited_urls.txt", \%visitedUrl);
            print("Saved visited link state!\n");
        }
        $countUrlParsed++;
    }



    # #Debug parsed urls
    # print("EMAILS:");
    # foreach my $newE (keys %newEmails)
    # {
    #     print("$newE\n");
    # }
    # print(" NEW LINKS:\n");
    # foreach my $newL (keys %newUrls)
    # {
    #     print("$newL\n");
    # }

    return %newUrls;
}

# PROGRAM:
# Load existing data into hastables
sub main
{
    # Load past crawler content into memory
    %foundEmail = loadFile("data/found_emails.txt", "H");
    %foundUrl = loadFile("data/found_urls.txt", "H");
    %visitedUrl = loadFile("data/visited_urls.txt", "H");
    %foundUrl = getDifference(\%foundUrl,\%visitedUrl);

    # # Total emails debug
    # my $numbers = scalar(keys(%foundEmail));
    # print("Amount emails already found: $numbers\n");
    # exit;

    # While the list of websites is not empty iterate over the urls to find more emails
    my %newEmails;
    my %newLinks;
    $countUrlParsed = 1;
    $visitedSaveInterval = 10;
    while(%foundUrl)
    {
        %newLinks = proccessURLS(\%foundUrl);

        #rewrite upto date links
        %foundUrl = %newLinks;
        saveAll("data/found_urls.txt", \%foundUrl);
        print("Saved found urls\n");
    }
}



print("Crawler Starter\n");
main();
print("Crawler Stoped\n");