#!/usr/bin/perl

# Tests of basic CIDER objects.

use warnings;
use strict;

use FindBin;
use lib (
    "$FindBin::Bin/../lib",
    "$FindBin::Bin/lib",
);     

use CIDERTest;
my $schema = CIDERTest->init_schema;

use Test::More;
use Test::Exception;

my @collections = $schema->resultset('Object')->root_objects;

is (scalar @collections, 2, 'There are two collections.');

my $collection_1 = $collections[0];
is ($collection_1->title, 'Test Collection with kids',
    'Collection\'s name is correct.'
);
isa_ok ($collection_1, 'CIDER::Schema::Result::Collection',
     'Collection'
 );
is( $collection_1->type, 'collection', 'type is collection.' );

is( $collection_1->language_name, 'English',
    'The collection language is English.' );

my @series = $collection_1->children;
is (scalar @series, 1, 'There is one child series.');

my $series_1 = $series[0];
is ( $series_1->title, 'Test Series 1',
     "The series' name is correct."
 );
isa_ok ($series_1, 'CIDER::Schema::Result::Series',
     'Series'
 );
is( $series_1->type, 'series', 'type is series.' );

my @items = $series_1->children;
is (scalar @items, 2, 'There are two child item.');

my ( $item_1, $item_2 ) = @items;

is ( $item_1->title, 'Test Item 1',
     "The item's name is correct."
 );
isa_ok ($item_1, 'CIDER::Schema::Result::Item',
     'Item'
 );
is( $item_1->type, 'item', 'type is item.' );

is ( $item_1->parent->id, $series_1->id,
     "The series is the parent of the item."
 );

use DateTime;

is( $item_1->date_from, '2000-01-01',
    "Item 1's date_from is correct." );

is( $item_2->date_to, '2010-01-01',
    "Item 2's date_to is correct." );

$item_2->date_to( '2011-01' );
$item_2->update;

is( $schema->resultset( 'Object' )->find( $item_2->id )->date_to, '2011-01',
    "Item 2's new date_to is correct." );

# TO DO: re-implement date ranges on collections and series.

# is( $collection_1->date_from, $item_1->date_from,
#     "The collection's date_from is the earliest date_from of its subitems.");

# is( $collection_1->date_to, $item_2->date_to,
#     "The collection's date_to is the latest date_to of its subitems.");

my $collection_2 = $collections[1];

is ($series_1->has_ancestor( $collection_2 ), 0,
    'Before moving, the series does not see the collection as ancestor.' );

$series_1->parent( $collection_2 );
$series_1->update;

is (scalar($collection_2->children), 1,
    'After moving, there is one child series in the second collection.');
is (scalar($collection_1->children), 0,
    'After moving, there are no child series in the first collection.');
is ($series_1->has_ancestor( $collection_2 ), 1,
    'After moving, the series claims the collection as ancestor.' );

throws_ok { $collection_2->parent( $series_1 ) } qr/ancestor/,
    "The series refuses to become its ancestor's parent.";

my $material = $collection_1->add_to_material( {
    material => 'Test Material 3'
} );
is( $collection_1->material->count, 3,
    'Has 3 associated materials after adding' );
$material->delete;
is( $collection_1->material->count, 2,
    'Has 2 associated materials after deleting' );
is( $collection_1->material->first, 'Test Material 1',
    'First associated material is correct' );
$collection_1->delete;
is( $schema->resultset( 'CollectionMaterial' )->count, 0,
    'Deleting collection deletes associated material' );

done_testing();
