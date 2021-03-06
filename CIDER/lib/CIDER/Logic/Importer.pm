package CIDER::Logic::Importer;

use Moose;
use XML::LibXML;
use Carp;

use CIDER::Schema;

has 'rngschema_file' => (
    is => 'rw',
    isa => 'Str',
);

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class',
);


sub import_from_xml {
    my $self = shift;
    my ( $handle ) = @_;

    # TO DO: catch errors while reading?
    binmode $handle;
    my $doc = XML::LibXML->load_xml( IO => $handle, line_numbers => 1 );

    # TO DO: load this statically?
    my $rngschema =
        XML::LibXML::RelaxNG->new( location => $self->rngschema_file );

    eval { $rngschema->validate( $doc ) };
    croak "XML import file is invalid:\n$@\n" if $@;

    my $schema = $self->schema;

    # All rows are inserted at once, or none at all if there are errors.
    $schema->txn_begin;
    $schema->indexer->txn_begin;

    my ( $created, $updated ) = ( 0, 0 );
    for my $cmd ( $doc->documentElement->getChildrenByTagName( '*' ) ) {
        my $create = $cmd->nodeName eq 'create';

        for my $elt ( $cmd->getChildrenByTagName( '*' ) ) {
            my $type = $elt->localname;
            my $class = ucfirst $elt->localname;
            my $rs = $schema->resultset( $class );

            eval {
                if ( $create ) {
                    $rs->create_from_xml( $elt );
                    $created++;
                } else {
                    $rs->update_from_xml( $elt );
                    $updated++;
                }
            };
            if ( $@ ) {
                my $err = $@;

                $schema->txn_rollback;
                $schema->indexer->txn_rollback;

                my $line = $elt->line_number;
                croak "XML import failed at line $line:\n$err\n";
            }
        }
    }

    $schema->txn_commit;
    $schema->indexer->txn_commit;

    return $created, $updated;
}

=head1 LICENSE

Copyright 2012 Tufts University

CIDER is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

CIDER is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with CIDER.  If not, see
<http://www.gnu.org/licenses/>.

=cut

1;
