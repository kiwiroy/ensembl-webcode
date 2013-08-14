# $Id$

package EnsEMBL::Web::Document::Element::StaticNav;

# Container HTML for left sided navigation menu on static pages 

use strict;

use HTML::Entities qw(encode_entities);
use URI::Escape    qw(uri_escape);
#use WWW::Mechanize;
#use WWW::Mechanize::TreeBuilder;

use base qw(EnsEMBL::Web::Document::Element::Navigation);

sub content {
  my $self = shift;
  my $html;

  ## LH MENU ------------------------------------------
  $html .= '<input type="hidden" class="panel_type" value="LocalContext" />
<div class="header">In this section</div>';

  $html .= '<ul class="local_context">';

  my $tree        = $self->species_defs->STATIC_INFO;
  my $here        = $ENV{'SCRIPT_NAME'};
  (my $pathstring = $here) =~ s/^\///; ## Remove leading slash
  my @path        = split '/', $pathstring;
  my $img_url     = $self->img_url;
  my $config      = $self->hub->session->get_data(type => 'nav', code => 'static') || {};

  ## Strip filename from current location - we just want directory
  (my $dir = $here) =~ s/^\/(.+\/)*(.+)\.(.+)$/$1/;
  
  ## Recurse into tree until you find current location
  my $this_tree = ($dir eq 'info/') ? $tree : $self->_walk_tree($tree, $dir, \@path, 1);

  my @pages = map { ref $this_tree->{$_} eq 'HASH' ? $_ : () } keys %$this_tree;
  my @page_order = sort {
    $this_tree->{$a}{'_order'} <=> $this_tree->{$b}{'_order'} ||
    $this_tree->{$a}{'_title'} cmp $this_tree->{$b}{'_title'} ||
    $this_tree->{$a}           cmp $this_tree->{$b}
  } @pages;

  my $last_page = $page_order[-1];
  foreach my $page (grep { !/^_/ && keys %{$this_tree->{$_}} } @page_order) {
    next unless $this_tree->{$page}{'_title'};

    my $url     = $page;
    $url       .= '/' unless $page =~ /html$/;
    (my $id     = $url) =~ s/\//_/g;
    my $class   = $page eq $last_page ? 'last' : 'top_level';
    my $state   = $config->{$page};
    my $toggle  = $state ? 'closed' : 'open';
    my @children  = grep { !/^_/ } keys %{$this_tree->{$page}};

    my $image = "${img_url}leaf.gif";
    my $submenu;
    if (scalar @children) {
      $class .= ' parent';
      my $last  = $children[-1];
      $submenu  = '<ul>';
      while (my($k,$v) = each(%{$this_tree->{$page}})) { 
        next unless ref($v) eq 'HASH';
        next unless $v->{'_title'};
        my $class = $k eq $last ? ' class="last"' : '';

        $submenu .= sprintf('<li%s><img src="%s"><a href="%s%s">%s</a></li>', 
                              $class, $image, $url, $k, $v->{'_title'});
      }
      $submenu .= '</ul>';
      $image    = "$img_url$toggle.gif";
    }

    $html .= sprintf('<li class="%s"><img src="%s" class="toggle %s" alt=""><a href="%s">%s</a>%s</li>', 
                        $class, $image, $id, $url, $this_tree->{$page}{'_title'}, $submenu); 
  }

  ## ----- IN-PAGE NAVIGATION ------------
=pod
  ### UNTESTED - AWAITING INSTALLATION OF MODULES ###

  ## Read the current file and parse out h2 headings with ids
  my $mech = WWW::Mechanize->new();
  WWW::Mechanize::TreeBuilder->meta->apply($mech);

  $mech->get($here);

  my @headers = $mech->find('h2');

  if (scalar(@headers) {
    ## Check the headers have id attribs we can link to
    my @id_headers;
    foreach (@headers) {
      push @id_headers, $_ if $_->attr('id');
    }

    ## Create submenu from these headers
    if (scalar(@id_headers) {
      $html .= '<div class="subheader">On this page</div>';
      $html .= '<ul class="local_context">';

      my $i = 0;
      foreach (@id_headers) {
        my $class = ($i == $#id_headers) ? 'class="last"' : '';
        $html .= sprintf('<li%s><a href="#%s">%s</a></li>', 
                          $class, $_->attr('id'), $_->as_text);
        $i++;
      }

      $html .= '</ul>';
    }
  }
=cut
  ## SEARCH -------------------------------------------

  my $img_url         = $self->img_url;
  my $search_url      = sprintf '%s%s/psychic', $self->home_url, 'Multi';

  $html .= qq(
    <div id="doc_search">
      <form action="$search_url">
        <div class="print_hide">
          <div class="header">Search documentation:</div>
          <input type="text" name="se_q" />
          <input type="image" class="button" src="${img_url}16/search.png" alt="Search&nbsp;&raquo;" />
        </div>
      </form>
    </div>
  );

  return $html;
}

sub _walk_tree {
  my ($self, $tree, $here, $path, $level) = @_;

  my $current_path = join('/', @$path[0..$level]).'/';
  my $sub_tree = $tree->{$path->[$level]};

  if ($sub_tree) {
    if ($current_path eq $here) {
      return $sub_tree;
    }
    else {
      ## Recurse
      $self->_walk_tree($sub_tree, $here, $path, $level+1);
    }
  }
  else {
    return $tree;
  }

}

1;
