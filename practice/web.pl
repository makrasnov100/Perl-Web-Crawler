#perl 5.22.1 

require HTTP::Request;
require LWP::UserAgent;

$req = HTTP::Request->new(GET => "https://www.whitworth.edu/cms");
$ua = LWP::UserAgent->new;
$response = $ua->request($req);
@resp = split(/\n/, $response->content);

foreach $r (@resp) {
    print $r."\n";
}