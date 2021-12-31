package Clib::Template::Package::Misc::Pdf;

use strict;
use warnings;

use Clib::Template::Package::Misc::Html;


sub tag_DATETIME { Clib::Template::Package::Misc::Html::tag_DATETIME(@_) }

sub tag_DATE { Clib::Template::Package::Misc::Html::tag_DATE(@_) }

sub tag_SIZE { Clib::Template::Package::Misc::Html::tag_SIZE(@_) }

sub tag_BYTE { Clib::Template::Package::Misc::Html::tag_BYTE(@_) }

sub tag_INTERVAL { Clib::Template::Package::Misc::Html::tag_INTERVAL(@_) }

sub tag_DUMPER { Clib::Template::Package::Misc::Html::tag_DUMPER(@_) }

sub tag_CSV { Clib::Template::Package::Misc::Html::tag_CSV(@_) }

1;
