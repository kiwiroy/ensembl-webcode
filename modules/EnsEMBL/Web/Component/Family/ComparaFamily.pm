=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Family::ComparaFamily;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Gene::FamilyProteins);

sub _get_details {
### Override parent method, so we can get the desired objects
### from the tree, not the gene
  my $self = shift;
  return (undef, $self->object->family);
}

1;
