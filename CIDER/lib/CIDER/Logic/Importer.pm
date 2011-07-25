package CIDER::Logic::Importer;

use strict;
use warnings;

use Moose;

use Text::CSV;
use Carp;

use CIDER::Schema;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class',
);

sub import_from_csv {
    my $self = shift;
    my ($handle) = @_;

    my $csv = Text::CSV->new;
    $csv->column_names( $csv->getline( $handle ) );

    my $schema = $self->schema;
    my $object_rs = $schema->resultset( 'Object' );

    # All rows are inserted at once, or none at all if there are errors.
    $schema->txn_begin;
    $schema->indexer->txn_begin;

    my $row_number = 0;
    while ( my $row = $csv->getline_hr( $handle ) ) {
        $row_number++;

        my $vals = { };

        my $object;
        if ( my $id = delete $row->{ id } ) {
            $object = $object_rs->find( $id );
        }

        if ( exists $row->{ parent } ) {
            if ( my $parent_num = delete $row->{ parent } ) {
                my $parent = $object_rs->find( { number => $parent_num } );
                unless ( $parent ) {
                    $object_rs->throw_exception(
                        "Unknown parent number: $parent_num" );
                }
                $vals->{ parent } = $parent;
            }
            else {
                $vals->{ parent } = undef;
            }
        }

        for my $field ( qw(number title) ) {
            if ( exists $row->{ $field } ) {
                if ( my $val = delete $row->{ $field } ) {
                    $vals->{ $field } = $val;
                }
                else {
                    $vals->{ $field } = undef;
                }
            }
        }

        my $type = delete $row->{ type };
        # TO DO: check that type is valid?
        unless ( $type ) {
            if ( $object ) {
                $type = $object->type;
            }
            # TO DO: else croak!
        }

        # Perform the actual update-or-insertion.
        eval {
            if ( $object ) {
                $object->update( $vals );
                unless ( $object->$type ) {
                    # TO DO: warn about change in type
                    # TO DO: copy shared fields?
                    $object->type_object->delete;
                }
                $object->update_or_create_related( $type, $row );
            }
            else {
                $vals->{ $type } = $row;
                $object = $object_rs->create( $vals );
            }
        };
        if ( $@ ) {
            my $err = $@;

            $schema->txn_rollback;
            $schema->indexer->txn_rollback;

            croak "CSV import failed at data row $row_number:\n$err\n";
        }
    }

    $schema->txn_commit;
    $schema->indexer->txn_commit;

    return $row_number;
}
1;
