use strict;
use warnings;
use Test::More;

eval "use Test::WWW::Mechanize::Catalyst 'CIDER'";
if ($@) {
    plan skip_all => 'Test::WWW::Mechanize::Catalyst required';
    exit 0;
}

use FindBin;
use lib (
    "$FindBin::Bin/lib",
    "$FindBin::Bin/../lib",
);
use CIDERTest;
my $schema = CIDERTest->init_schema;

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

use_ok( 'CIDER::Controller::Object' );

$mech->get_ok( '/object' );

$mech->submit_form( with_fields => {
    username => 'alice',
    password => 'foo',
} );

$mech->submit_form_ok( { with_fields => { type => 'collection' } },
    'Asked for collection creation form' );

$mech->content_contains( 'Create a new collection' );

$mech->submit_form_ok( { with_fields => {
    title => 'New test collection',
    number => '69105',
    date_from => '2000-01-01',
    date_to => '2010-01-01',
    scope => 'oscillo',
} }, 'Submitted creation form' );

$mech->content_contains( 'You have successfully created' );

my $rs = $schema->resultset( 'Collection' )->search( { number => '69105' } );
is( $rs->first->creator->username, 'alice', 'Creator is alice.' );


done_testing();
