package Clib::Template::Package::Base::Excel;

use strict;
use warnings;

use Clib::Template::Package::Base::Pdf;


sub tag_DEFAULT     { Clib::Template::Package::Base::Pdf::tag_DEFAULT(@_); }

sub tag_RAW         { Clib::Template::Package::Base::Pdf::tag_RAW(@_); }

sub tag_TEXT        { Clib::Template::Package::Base::Pdf::tag_TEXT(@_); }


sub tag_IF          { Clib::Template::Package::Base::Pdf::tag_IF(@_); }


sub tag_FOREACH     { Clib::Template::Package::Base::Pdf::tag_FOREACH(@_); }

sub tag_INCLUDE     { Clib::Template::Package::Base::Pdf::tag_INCLUDE(@_); }


1;
