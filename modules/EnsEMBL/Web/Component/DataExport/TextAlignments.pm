=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::DataExport::TextAlignments;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Alignments);

sub content {
  ### Options for gene sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  ## Get user's current settings
  my $viewconfig  = $hub->get_viewconfig($hub->param('component'), $hub->param('data_type'));

  my $settings = {
        'Hidden' => ['align'],
        'flank5_display' => {
            'label'     => "5' Flanking sequence (upstream)",  
            'type'      => 'NonNegInt',  
        },
        'flank3_display' => { 
            'label'     => "3' Flanking sequence (downstream)", 
            'type'      => 'NonNegInt',  
        },
        'snp_display' => {
            'label'   => 'Include sequence variants',
            'type'    => 'Checkbox',
            'value'   => 'on',
            'checked' => $viewconfig->get('snp_display') eq 'off' ? 0 : 1,
        },
  };

  ## Options per format
  my $fields_by_format = {
    'RTF' => [
                ['flank5_display',  $viewconfig->get('flank5_display')], 
                ['flank3_display',  $viewconfig->get('flank3_display')],
                ['snp_display'],
              ],  
  };
  ## Add formats output by BioPerl
  foreach ($self->alignment_formats) {
    $fields_by_format->{$_} = [];
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

1;