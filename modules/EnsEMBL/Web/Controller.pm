# $Id$

package EnsEMBL::Web::Controller;

use strict;

use Apache2::RequestUtil;
use CGI;

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::Data::Record::History;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Tree;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my $r     = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args  = shift || {};
  my $input = new CGI;
  
  my $object_params = [
    [ 'Location',            'r'   ],
    [ 'Gene',                'g'   ],
    [ 'Transcript',          't'   ],
    [ 'Variation',           'v'   ],
    [ 'StructuralVariation', 'sv'  ],
    [ 'Regulation',          'rf'  ],
    [ 'Marker',              'm'   ],
    [ 'LRG',                 'lrg' ],
    [ 'GeneTree',            'gt'  ],
  ];
  
  my $object_types    = { map { $_->[0] => $_->[1] } @$object_params };
  my $ordered_objects = [ map $_->[0], @$object_params ];
  
  my $hub = new EnsEMBL::Web::Hub({
    apache_handle  => $r,
    input          => $input,
    object_types   => $object_types,
    session_cookie => $args->{'session_cookie'},
    user_cookie    => $args->{'user_cookie'},
  });
  
  my $builder = new EnsEMBL::Web::Builder({
    hub             => $hub,
    object_params   => $object_params,
    object_types    => $object_types,
    ordered_objects => $ordered_objects
  });
  
  my $self = {
    r             => $r,
    input         => $input,
    hub           => $hub,
    builder       => $builder,
    cache         => $hub->cache,
    type          => $hub->type,
    action        => $hub->action,
    function      => $hub->function,
    command       => undef,
    filters       => undef,
    errors        => [],
    page_type     => 'Dynamic',
    renderer_type => 'String',
    %$args
  };
  
  my $species_defs = $hub->species_defs;
  
  if ($self->{'cache'}) {
    # Add parameters useful for caching functions
    $self = {
      %$self,
      session_id  => $hub->session->session_id,
      user_id     => $hub->user,
      url_tag     => $species_defs->ENSEMBL_BASE_URL . $ENV{'REQUEST_URI'},
      cache_debug => $species_defs->ENSEMBL_DEBUG_FLAGS & $species_defs->ENSEMBL_DEBUG_MEMCACHED
    }
  }
  
  bless $self, $class;
  
  $CGI::POST_MAX = $species_defs->CGI_POST_MAX; # Set max upload size
  
  $self->init;
  
  return $self;
}

sub init {}

sub r             { return $_[0]->{'r'};              }
sub input         { return $_[0]->{'input'};          }
sub hub           { return $_[0]->{'hub'};            }
sub builder       { return $_[0]->{'builder'};        }
sub cache         { return $_[0]->{'cache'};          }
sub errors        { return $_[0]->{'errors'};         }
sub type          { return $_[0]->hub->type;          }
sub action        { return $_[0]->hub->action;        }
sub function      { return $_[0]->hub->function;      }
sub species_defs  { return $_[0]->hub->species_defs;  }
sub object        { return $_[0]->builder->object;    }
sub page_type     { return $_[0]->{'page_type'};      }
sub renderer_type { return $_[0]->{'renderer_type'};  }
sub request       { return undef;                     }
sub cacheable     { return 0;                         }
sub node          :lvalue { $_[0]->{'node'};          }
sub command       :lvalue { $_[0]->{'command'};       }
sub filters       :lvalue { $_[0]->{'filters'};       }

sub renderer {
  my $self = shift;
  
  if (!$self->{'renderer'}) {
    my $renderer_module = 'EnsEMBL::Web::Document::Renderer::' . $self->renderer_type;
    
    ($self->{'renderer'}) = $self->_use($renderer_module, (
      r     => $self->r,
      cache => $self->cache
    ));
  }
  
  return $self->{'renderer'};
}

sub page {
  my $self       = shift;
  my $outputtype = $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/ ? 'search_bot' : shift;
  
  if (!$self->{'page'}) {
    my $document_module = 'EnsEMBL::Web::Document::Page::' . $self->page_type;
    
    ($self->{'page'}) = $self->_use($document_module, {
      input        => $self->input,
      hub          => $self->hub, 
      species_defs => $self->species_defs, 
      renderer     => $self->renderer,
      outputtype   => $outputtype
    });
  }
  
  return $self->{'page'};
}

sub configuration {
  my $self = shift;
  my $hub  = $self->hub;
  
  if (!$self->{'configuration'}) {
    my $conf = {
      tree         => new EnsEMBL::Web::Tree,
      default      => undef,
      action       => undef,
      configurable => 0,
      page_type    => $self->page_type
    };
    
    my $module_name = 'EnsEMBL::Web::Configuration::' . $hub->type;
    my ($configuration, $error) = $self->_use($module_name, $self->page, $hub, $self->builder, $conf);
    
    if ($error) {
      # Handle "use" failures gracefully, but skip "Can't locate" errors
      $self->add_error( 
        'Configuration module compilation error',
        '<p>Unable to use Configuration module <strong>%s</strong> due to the following error:</p><pre>%s</pre>',
        $module_name, $error
      );
    }
    
    $self->{'configuration'} = $configuration;
  } elsif (!$self->{'configuration'}{'object'} && $self->object) {
    $self->{'configuration'}{'object'} = $self->object;
    $self->{'configuration'}->set_action($hub->action, $hub->function);
  }
  
  return $self->{'configuration'};
}

sub configure {
  my $self          = shift;
  my $hub           = $self->hub;
  my $configuration = $self->configuration;
  my $node          = $configuration->get_node($configuration->get_valid_action($self->action, $self->function));
  
  if ($node) {
    $self->node    = $node;
    $self->command = $node->data->{'command'};
    $self->filters = $node->data->{'filters'};
  }
  
  if ($hub->object_types->{$hub->type}) {
    $hub->components = $configuration->get_configurable_components($node);
  } elsif ($self->request eq 'modal') {
    my $referer     = $hub->referer;
    my $module_name = "EnsEMBL::Web::Configuration::$referer->{'ENSEMBL_TYPE'}";
    
    $hub->components = $module_name->new_for_components($hub, { tree => new EnsEMBL::Web::Tree }, $referer->{'ENSEMBL_ACTION'}, $referer->{'ENSEMBL_FUNCTION'}) if $self->dynamic_use($module_name);
  }
}

sub render_page {
  my $self     = shift;
  my $page     = $self->page;
  my $hub      = $self->hub;
  my $func     = $self->renderer->{'_modal_dialog_'} ? 'get_json' : 'content';
  my $elements = $page->elements;
  my @order    = map $_->[0], @{$page->head_order}, @{$page->body_order};
  my $content  = {};
  
  foreach my $element (@order) {
    my $module = $elements->{$element};
    $module->init($self) if $module->can('init');
  }
  
  foreach my $element (@order) {
    my $module = $elements->{$element};
    $content->{$element} = $module->$func();
  }
  
  my $page_content = $page->render($content);
  
  $self->set_cached_content($page_content) if $page->{'format'} eq 'HTML' && !$self->hub->has_a_problem;
}

sub update_user_history {
  my $self            = shift;
  my $hub             = $self->hub;
  my $user            = $hub->user;
  my $referer         = $hub->referer;
  my $referer_type    = $referer->{'ENSEMBL_TYPE'};
  my $referer_species = $referer->{'ENSEMBL_SPECIES'};
  my $param           = $hub->object_types->{$referer_type};
  
  if ($referer_type && $param) {
    my @type_history = grep $_->{'object'} eq $referer_type, $user->histories;
    my $value        = shift || $referer->{'params'}->{$param}->[0];
    my $name         = $self->species_defs->get_config($referer_species, 'SPECIES_COMMON_NAME');
    
    if ($referer_type =~ /^(Gene|Transcript)$/) {
      my $db           = $referer->{'params'}->{'db'}->[0] || 'core';
      $db              = 'otherfeatures' if $db eq 'est';
      my $func         = "get_${referer_type}Adaptor";
      my $feature      = $hub->get_adaptor($func, $db, $referer_species)->fetch_by_stable_id($value);
      my $display_xref = $feature ? $feature->display_xref : undef;
      
      $name .= ': ' . ($display_xref ? $display_xref->display_id : $value);
    } else {
      $name .= $name ? ": $value" : $value;
    }
    
    my $name_check = grep { $_->{'name'} eq $name } @type_history;
    
    if ($value && !$name_check && !($referer_type eq $self->type && $hub->param($param) eq $value)) {
      my $history = new EnsEMBL::Web::Data::Record::History::User({ user_id => $user->id });
      $history->name($name);
      $history->species($referer_species);
      $history->object($referer_type);
      $history->param($param);
      $history->value($value);
      $history->url($referer->{'absolute_url'});
      $history->save;
      
      ## Limit to 5 entries per object type
      shift(@type_history)->delete while scalar @type_history >= 5; 
    }
  }
}

sub set_cache_params {
  my ($self, $type) = @_;
  
  $ENV{'CACHE_TAGS'}{'DYNAMIC'} = 1;
  $ENV{'CACHE_TAGS'}{'AJAX'}    = 1;

  $ENV{'CACHE_KEY'}  = $ENV{'REQUEST_URI'};
  
  if ($self->{'session_id'}) {
    $ENV{'CACHE_KEY'} .= "::SESSION[$self->{'session_id'}]"
  } else {
    $ENV{'CACHE_KEY'} .= '::MAC'  if $ENV{'HTTP_USER_AGENT'} =~ /Macintosh/;
    $ENV{'CACHE_KEY'} .= "::IE$1" if $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d)/;
  }
  
  $ENV{'CACHE_KEY'} .= '::BOT' if $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/;
  
  if ($type eq 'page') {
    $ENV{'CACHE_TAGS'}{$self->{'url_tag'}} = 1;
    $ENV{'CACHE_KEY'} .= "::USER[$self->{'user_id'}]" if $self->{'user_id'};
  } else {
    $ENV{'CACHE_TAGS'}{$ENV{'HTTP_REFERER'}} = 1;
    $ENV{'CACHE_KEY'} .= "::WIDTH[$ENV{ENSEMBL_IMAGE_WIDTH}]" if $ENV{'ENSEMBL_IMAGE_WIDTH'};
  }
}

sub get_cached_content {
  ### Attempt to retrieve page and component requests from Memcached
  
  my ($self, $type) = @_;
  
  my $cache = $self->cache;
  my $r     = $self->r;
  
  return unless $cache;
  return if $r->method eq 'POST';
  return unless $type =~ /^(page|component)$/;
  
  $self->set_cache_params($type);
  
  my $content = $cache->get($ENV{'CACHE_KEY'}, keys %{$ENV{'CACHE_TAGS'}});
  
  if ($content) {
    $r->headers_out->set('X-MEMCACHED' => 'yes');     
    $r->content_type('text/html');
    
    print $content;
    
    warn "CONTENT CACHE HIT:  $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
  } else {
    warn "CONTENT CACHE MISS: $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
  }
  
  return !!$content;
}

sub set_cached_content {
  ### Attempt to add page and component requests to Memcached
  
  my ($self, $content) = @_;
  
  my $cache = $self->cache;
  
  return unless $cache && $self->cacheable;
  return unless $ENV{'CACHE_KEY'};
  return if $self->r->method eq 'POST';
  
  $cache->set($ENV{'CACHE_KEY'}, $content, 60*60*24*7, keys %{$ENV{'CACHE_TAGS'}});
  
  warn "CONTENT CACHE SET:  $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
}

sub clear_cached_content {
  ### Flush the cache if the user has hit ^R or F5.
  ### Removes content from Memcached based on the request's URL and the user's session id.
  
  my $self  = shift;
  my $cache = $self->cache;
  my $r     = $self->r;
  
  if ($cache && $r->headers_in->{'Cache-Control'} =~ /(max-age=0|no-cache)/ && $r->method ne 'POST') {
    $cache->delete_by_tags($self->{'url_tag'}, $self->{'session_id'} ? "session_id[$self->{'session_id'}]" : (), $self->{'user_id'} ? "user[$self->{'user_id'}]" : ());
    
    warn "CONTENT CACHE CLEAR: $self->{'url_tag'}, $self->{'session_id'}, $self->{'user_id'}" if $self->{'cache_debug'};
  }
}

sub add_error {
 ### Wrapper for add_panel
 
 my ($self, $caption, $template, @content) = @_;
 my $error = $self->_format_error(pop @content);
 push @{$self->errors}, new EnsEMBL::Web::Document::Panel(caption => $caption, content => sprintf($template, @content, $error));
}

sub _use {
  ### Wrapper for EnsEMBL::Web::Root::dynamic_use.
  ### Returns either a newly created module or the error detailing why the new function failed.
  ### Skips "Can't locate" errors - these come from trying to use non-existant modules in plugin directories and can be safely ignored.
  
  my $self        = shift;
  my $module_name = shift;
  
  my $module = $self->dynamic_use($module_name) && $module_name->can('new') ? $module_name->new(@_) : undef;
  my $error;
  
  if (!$module) {
    $error = $self->dynamic_use_failure($module_name);
    $error = undef if $error =~ /^Can't locate/;
  }
  
  return ($module, $error);
}

sub DESTROY { Bio::EnsEMBL::Registry->disconnect_all; }

1;
