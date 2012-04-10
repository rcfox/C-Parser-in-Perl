#!/usr/bin/perl
use strict;
use warnings;
use Marpa::XS;
use List::MoreUtils qw(firstidx);
use Data::Dumper;

sub lexer {
	my $rec = shift;
	my $line = shift;
	$line =~ s/^#.*//g;
	$line =~ s/\s+/ /g;
	$line =~ s|//.*||g;
	$line =~ s|/\*[\s\S]*\*/||g;
	while($line ne '') {
		$line =~ s/^\s//;
		if($line =~ s/^(\[)//) {
			$rec->read('lbracket',$1);
		}
		if($line =~ s/^(\])//) {
			$rec->read('rbracket',$1);
		}
		if($line =~ s/^(,)//) {
			$rec->read('comma',$1);
		}
		if($line =~ s/^(\W)//) {
			$rec->read($1,$1);
		}
		if($line =~ s/^(\d+(\.\d+))//) {
			$rec->read('float_const',$1);
		}
		if($line =~ s/^(\d+)//) {
			$rec->read('int_const',$1);
		}
		if($line =~ s/^(enum)//) {
			$rec->read($1,$1);
		}
		if($line =~ s/^(struct|union)//) {
			$rec->read('struct_or_union',$1);
		}
		if($line =~ s/^(const|volatile)//) {
			$rec->read('type_qualifier',$1);
		}
		if($line =~ s/^(void|char|short|int|long|float|double|signed|unsigned)//) {
			$rec->read('type_spec',$1);
		}
		if($line =~ s/^(\w+)//) {
			$rec->read('id',$1);
		}
	}
}

sub action::value { return $_[1]; }
sub action::value2 { return $_[2]; }

sub action::list {
	shift;
	return \@_;
}

sub action::hash {
	shift;
	my %hash;
	foreach(@_) {
		my %h = %{$_};
		@hash{keys %h} = values %h;
	}
	return \%hash;
}

sub action::circular_sequence {
	shift;
	my @list = ($_[0]);
	push @list, @{$_[1]} if ($_[1]);
	return \@list;
}

my %unnamed = ( enum => 0, struct => 0, union => 0 );
sub action::struct_or_union_spec {
	shift;
	my $type = firstidx { $_ ~~ /struct|union|enum/ } @_;
	my $brace = firstidx { $_ eq '{' } @_;
	my $name = $_[$type+1];
	$type = $_[$type];
	if($brace == -1) {
		return { $type => $name };
	}
	if($name eq $_[$brace]) {
		$name = "unnamed_$type$unnamed{$type}";
		++$unnamed{$type};
	}
	return { $type => $name, elements => $_[$brace+1] };
}

sub action::enum_spec {
	action::struct_or_union_spec(@_);
}

sub action::enumerator_list {
	shift;
	my $next = $_[0]->[1] || 0;
	for(@_)
	{
		if(!defined($_->[1])) {
			$_->[1] = $next;
		}
		$next = $_->[1]+1;
	}
	return \@_;
}

sub action::enumerator {
	my $name = $_[1];
	my $value = $_[3];
	return [$name,$value];
}

sub action::struct_decl {
	shift;
	my %struct;
	my @types = @{$_[0]};
	my @elements = @{$_[1]};
	for(@elements) {
		if(ref eq 'ARRAY') { # add pointers to the type
			$struct{$_->[0]} = [@types, @{$_->[1]}];
		} else {
			$struct{$_} = [@types];
		}
	}
	return \%struct;
}


sub action::pointer_declarator {
	shift;
	sub flatten {
		map { ref eq 'ARRAY' ? flatten(@$_) : $_ } @_
	}
	my @list = flatten($_[0]);
	return [$_[1],[@list]];
}

sub action::direct_declarator_array {
	shift;
	return [$_[0],["[$_[2]]"]];
}


sub action::function_definition {
	#print Dumper(\@_);
	shift;
	return \@_;
}

my $rules = [{ lhs => 'translation_unit', rhs => [qw/external_decl/], action => 'list'},
         { lhs => 'translation_unit', rhs => [qw/translation_unit external_decl/], action => 'list'},
         { lhs => 'external_decl', rhs => [qw/function_definition/], },
         { lhs => 'external_decl', rhs => [qw/decl/], },
         { lhs => 'function_definition', rhs => [qw/decl_specs declarator decl_list compound_stat/], },
         { lhs => 'function_definition', rhs => [qw/declarator decl_list compound_stat/], },
         { lhs => 'function_definition', rhs => [qw/decl_specs declarator compound_stat/], },
         { lhs => 'function_definition', rhs => [qw/declarator compound_stat/], },
         { lhs => 'decl', rhs => [qw/decl_specs init_declarator_list ;/], },
         { lhs => 'decl', rhs => [qw/decl_specs ;/], },
         { lhs => 'decl_list', rhs => [qw/decl/], min => 1, action => 'list' },
         { lhs => 'decl_specs', rhs => [qw/storage_class_spec decl_specs/], action => 'circular_sequence'},
         { lhs => 'decl_specs', rhs => [qw/storage_class_spec/], action => 'circular_sequence'},
         { lhs => 'decl_specs', rhs => [qw/type_spec decl_specs/], action => 'circular_sequence'},
         { lhs => 'decl_specs', rhs => [qw/type_spec/], action => 'circular_sequence'},
         { lhs => 'decl_specs', rhs => [qw/type_qualifier decl_specs/], action => 'circular_sequence'},
         { lhs => 'decl_specs', rhs => [qw/type_qualifier/], action => 'circular_sequence'},
         { lhs => 'storage_class_spec', rhs => [qw/auto/], },
         { lhs => 'storage_class_spec', rhs => [qw/register/], },
         { lhs => 'storage_class_spec', rhs => [qw/static/], },
         { lhs => 'storage_class_spec', rhs => [qw/extern/], },
         { lhs => 'storage_class_spec', rhs => [qw/typedef/], },
         { lhs => 'type_spec', rhs => [qw/void/], },
         { lhs => 'type_spec', rhs => [qw/char/], },
         { lhs => 'type_spec', rhs => [qw/short/], },
         { lhs => 'type_spec', rhs => [qw/int/], },
         { lhs => 'type_spec', rhs => [qw/long/], },
         { lhs => 'type_spec', rhs => [qw/float/], },
         { lhs => 'type_spec', rhs => [qw/double/], },
         { lhs => 'type_spec', rhs => [qw/signed/], },
         { lhs => 'type_spec', rhs => [qw/unsigned/], },
         { lhs => 'type_spec', rhs => [qw/struct_or_union_spec/], },
         { lhs => 'type_spec', rhs => [qw/enum_spec/], },
         { lhs => 'type_spec', rhs => [qw/typedef_name/], },
         { lhs => 'type_qualifier', rhs => [qw/const/], },
         { lhs => 'type_qualifier', rhs => [qw/volatile/], },
         { lhs => 'struct_or_union_spec', rhs => [qw/struct_or_union id { struct_decl_list }/], },
         { lhs => 'struct_or_union_spec', rhs => [qw/struct_or_union { struct_decl_list }/], },
         { lhs => 'struct_or_union_spec', rhs => [qw/struct_or_union id/], },
         { lhs => 'struct_or_union', rhs => [qw/struct/], },
         { lhs => 'struct_or_union', rhs => [qw/union/], },
         { lhs => 'struct_decl_list', rhs => [qw/struct_decl/], min => 1, action => 'hash' },
         { lhs => 'init_declarator_list', rhs => [qw/init_declarator/], min => 1, separator => 'comma', action => 'list', },
         { lhs => 'init_declarator', rhs => [qw/declarator/], },
         { lhs => 'init_declarator', rhs => [qw/declarator = initializer/], },
         { lhs => 'struct_decl', rhs => [qw/spec_qualifier_list struct_declarator_list ;/], },
         { lhs => 'spec_qualifier_list', rhs => [qw/type_spec spec_qualifier_list/], action => 'circular_sequence'},
         { lhs => 'spec_qualifier_list', rhs => [qw/type_spec/], action => 'circular_sequence'},
         { lhs => 'spec_qualifier_list', rhs => [qw/type_qualifier spec_qualifier_list/], action => 'circular_sequence'},
         { lhs => 'spec_qualifier_list', rhs => [qw/type_qualifier/], action => 'circular_sequence'},
         { lhs => 'struct_declarator_list', rhs => [qw/struct_declarator/], min => 1, separator => 'comma', action => 'list', },
         { lhs => 'struct_declarator', rhs => [qw/declarator/], },
         { lhs => 'struct_declarator', rhs => [qw/declarator  : const_exp/], },
         { lhs => 'struct_declarator', rhs => [qw/ : const_exp/], },
         { lhs => 'enum_spec', rhs => [qw/enum id { enumerator_list }/], },
         { lhs => 'enum_spec', rhs => [qw/enum { enumerator_list }/], },
         { lhs => 'enum_spec', rhs => [qw/enum id/], },
         { lhs => 'enumerator_list', rhs => [qw/enumerator/], min => 1, separator => 'comma' },
         { lhs => 'enumerator', rhs => [qw/id/], },
         { lhs => 'enumerator', rhs => [qw/id = const_exp/], },
         { lhs => 'declarator', rhs => [qw/pointer direct_declarator/], action => 'pointer_declarator'},
         { lhs => 'declarator', rhs => [qw/direct_declarator/], },
         { lhs => 'direct_declarator', rhs => [qw/id/], },
         { lhs => 'direct_declarator', rhs => [qw/( declarator )/], action => 'value2'},
         { lhs => 'direct_declarator', rhs => [qw/direct_declarator lbracket const_exp rbracket/], action => 'direct_declarator_array'},
         { lhs => 'direct_declarator', rhs => [qw/direct_declarator lbracket rbracket/], },
         { lhs => 'direct_declarator', rhs => [qw/direct_declarator ( param_type_list )/], },
         { lhs => 'direct_declarator', rhs => [qw/direct_declarator ( id_list )/], },
         { lhs => 'direct_declarator', rhs => [qw/direct_declarator ( )/], },
         { lhs => 'pointer', rhs => [qw/* type_qualifier_list/], },
         { lhs => 'pointer', rhs => [qw/*/], },
         { lhs => 'pointer', rhs => [qw/* type_qualifier_list pointer/], },
         { lhs => 'pointer', rhs => [qw/* pointer/], action => 'list'},
         { lhs => 'type_qualifier_list', rhs => [qw/type_qualifier/], min => 1, action => 'list'},
         { lhs => 'param_type_list', rhs => [qw/param_list/], },
         { lhs => 'param_type_list', rhs => [qw/param_list comma .../], },
         { lhs => 'param_list', rhs => [qw/param_decl/], min => 1, separator => 'comma', action => 'list', },
         { lhs => 'param_decl', rhs => [qw/decl_specs declarator/], },
         { lhs => 'param_decl', rhs => [qw/decl_specs abstract_declarator/], },
         { lhs => 'param_decl', rhs => [qw/decl_specs/], },
         { lhs => 'id_list', rhs => [qw/id/], min => 1, separator => 'comma', action => 'list', },
         { lhs => 'initializer', rhs => [qw/assignment_exp/], },
         { lhs => 'initializer', rhs => [qw/{ initializer_list }/], },
         { lhs => 'initializer', rhs => [qw/{ initializer_list comma }/], },
         { lhs => 'initializer_list', rhs => [qw/initializer/], min => 1, separator => 'comma', action => 'list', },
         { lhs => 'type_name', rhs => [qw/spec_qualifier_list abstract_declarator/], },
         { lhs => 'type_name', rhs => [qw/spec_qualifier_list/], },
         { lhs => 'abstract_declarator', rhs => [qw/pointer/], },
         { lhs => 'abstract_declarator', rhs => [qw/pointer direct_abstract_declarator/], },
         { lhs => 'abstract_declarator', rhs => [qw/direct_abstract_declarator/], },
         { lhs => 'direct_abstract_declarator', rhs => [qw/( abstract_declarator )/], action => 'value2'},
         { lhs => 'direct_abstract_declarator', rhs => [qw/direct_abstract_declarator lbracket const_exp rbracket/], },
         { lhs => 'direct_abstract_declarator', rhs => [qw/lbracket const_exp rbracket/], action => 'value2'},
         { lhs => 'direct_abstract_declarator', rhs => [qw/direct_abstract_declarator lbracket rbracket/], },
         { lhs => 'direct_abstract_declarator', rhs => [qw/lbracket rbracket/], },
         { lhs => 'direct_abstract_declarator', rhs => [qw/direct_abstract_declarator ( param_type_list )/], },
         { lhs => 'direct_abstract_declarator', rhs => [qw/( param_type_list )/], action => 'value2'},
         { lhs => 'direct_abstract_declarator', rhs => [qw/direct_abstract_declarator ( )/], },
         { lhs => 'direct_abstract_declarator', rhs => [qw/( )/], },
         { lhs => 'typedef_name', rhs => [qw/id/], },
         { lhs => 'stat', rhs => [qw/labeled_stat/], },
         { lhs => 'stat', rhs => [qw/exp_stat/], },
         { lhs => 'stat', rhs => [qw/compound_stat/], },
         { lhs => 'stat', rhs => [qw/selection_stat/], },
         { lhs => 'stat', rhs => [qw/iteration_stat/], },
         { lhs => 'stat', rhs => [qw/jump_stat/], },
         { lhs => 'labeled_stat', rhs => [qw/id  : stat/], },
         { lhs => 'labeled_stat', rhs => [qw/case const_exp  : stat/], },
         { lhs => 'labeled_stat', rhs => [qw/default  : stat/], },
         { lhs => 'exp_stat', rhs => [qw/exp ;/], },
         { lhs => 'exp_stat', rhs => [qw/;/], },
         { lhs => 'compound_stat', rhs => [qw/{ decl_list stat_list }/], },
         { lhs => 'compound_stat', rhs => [qw/{ stat_list }/], action => 'value2'},
         { lhs => 'compound_stat', rhs => [qw/{ decl_list }/], action => 'value2'},
         { lhs => 'compound_stat', rhs => [qw/{ }/], },
         { lhs => 'stat_list', rhs => [qw/stat/], min => 1},
         { lhs => 'selection_stat', rhs => [qw/if ( exp ) stat/], },
         { lhs => 'selection_stat', rhs => [qw/if ( exp ) stat else stat/], },
         { lhs => 'selection_stat', rhs => [qw/switch ( exp ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/while ( exp ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/do stat while ( exp ) ;/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( exp ; exp ; exp ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( exp ; exp ; ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( exp ; ; exp ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( exp ; ; ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( ; exp ; exp ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( ; exp ; ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( ; ; exp ) stat/], },
         { lhs => 'iteration_stat', rhs => [qw/for ( ; ; ) stat/], },
         { lhs => 'jump_stat', rhs => [qw/goto id ;/], },
         { lhs => 'jump_stat', rhs => [qw/continue ;/], },
         { lhs => 'jump_stat', rhs => [qw/break ;/], },
         { lhs => 'jump_stat', rhs => [qw/return exp ;/], },
         { lhs => 'jump_stat', rhs => [qw/return ;/], },
         { lhs => 'exp', rhs => [qw/assignment_exp/], },
         { lhs => 'exp', rhs => [qw/exp comma assignment_exp/], },
         { lhs => 'assignment_exp', rhs => [qw/conditional_exp/], },
         { lhs => 'assignment_exp', rhs => [qw/unary_exp assignment_operator assignment_exp/], },
         { lhs => 'assignment_operator', rhs => [qw/=/], },
         { lhs => 'assignment_operator', rhs => [qw/*=/], },
         { lhs => 'assignment_operator', rhs => [qw/\/=/], },
         { lhs => 'assignment_operator', rhs => [qw/%=/], },
         { lhs => 'assignment_operator', rhs => [qw/+=/], },
         { lhs => 'assignment_operator', rhs => [qw/-=/], },
         { lhs => 'assignment_operator', rhs => [qw/<<=/], },
         { lhs => 'assignment_operator', rhs => [qw/>>=/], },
         { lhs => 'assignment_operator', rhs => [qw/&=/], },
         { lhs => 'assignment_operator', rhs => [qw/^=/], },
         { lhs => 'assignment_operator', rhs => [qw/|=/], },
         { lhs => 'conditional_exp', rhs => [qw/logical_or_exp/], },
         { lhs => 'conditional_exp', rhs => [qw/logical_or_exp ? exp  : conditional_exp/], },
         { lhs => 'const_exp', rhs => [qw/conditional_exp/], },
         { lhs => 'logical_or_exp', rhs => [qw/logical_and_exp/], },
         { lhs => 'logical_or_exp', rhs => [qw/logical_or_exp || logical_and_exp/], },
         { lhs => 'logical_and_exp', rhs => [qw/inclusive_or_exp/], },
         { lhs => 'logical_and_exp', rhs => [qw/logical_and_exp && inclusive_or_exp/], },
         { lhs => 'inclusive_or_exp', rhs => [qw/exclusive_or_exp/], },
         { lhs => 'inclusive_or_exp', rhs => [qw/inclusive_or_exp | exclusive_or_exp/], },
         { lhs => 'exclusive_or_exp', rhs => [qw/and_exp/], },
         { lhs => 'exclusive_or_exp', rhs => [qw/exclusive_or_exp ^ and_exp/], },
         { lhs => 'and_exp', rhs => [qw/equality_exp/], },
         { lhs => 'and_exp', rhs => [qw/and_exp & equality_exp/], },
         { lhs => 'equality_exp', rhs => [qw/relational_exp/], },
         { lhs => 'equality_exp', rhs => [qw/equality_exp == relational_exp/], },
         { lhs => 'equality_exp', rhs => [qw/equality_exp != relational_exp/], },
         { lhs => 'relational_exp', rhs => [qw/shift_expression/], },
         { lhs => 'relational_exp', rhs => [qw/relational_exp < shift_expression/], },
         { lhs => 'relational_exp', rhs => [qw/relational_exp > shift_expression/], },
         { lhs => 'relational_exp', rhs => [qw/relational_exp <= shift_expression/], },
         { lhs => 'relational_exp', rhs => [qw/relational_exp >= shift_expression/], },
         { lhs => 'shift_expression', rhs => [qw/additive_exp/], },
         { lhs => 'shift_expression', rhs => [qw/shift_expression << additive_exp/], },
         { lhs => 'shift_expression', rhs => [qw/shift_expression >> additive_exp/], },
         { lhs => 'additive_exp', rhs => [qw/mult_exp/], },
         { lhs => 'additive_exp', rhs => [qw/additive_exp + mult_exp/], },
         { lhs => 'additive_exp', rhs => [qw/additive_exp - mult_exp/], },
         { lhs => 'mult_exp', rhs => [qw/cast_exp/], },
         { lhs => 'mult_exp', rhs => [qw/mult_exp * cast_exp/], },
         { lhs => 'mult_exp', rhs => [qw/mult_exp \/ cast_exp/], },
         { lhs => 'mult_exp', rhs => [qw/mult_exp % cast_exp/], },
         { lhs => 'cast_exp', rhs => [qw/unary_exp/], },
         { lhs => 'cast_exp', rhs => [qw/( type_name ) cast_exp/], },
         { lhs => 'unary_exp', rhs => [qw/postfix_exp/], },
         { lhs => 'unary_exp', rhs => [qw/++ unary_exp/], },
         { lhs => 'unary_exp', rhs => [qw/-- unary_exp/], },
         { lhs => 'unary_exp', rhs => [qw/unary_operator cast_exp/], },
         { lhs => 'unary_exp', rhs => [qw/sizeof unary_exp/], },
         { lhs => 'unary_exp', rhs => [qw/sizeof ( type_name )/], },
         { lhs => 'unary_operator', rhs => [qw/&/], },
         { lhs => 'unary_operator', rhs => [qw/*/], },
         { lhs => 'unary_operator', rhs => [qw/+/], },
         { lhs => 'unary_operator', rhs => [qw/-/], },
         { lhs => 'unary_operator', rhs => [qw/~/], },
         { lhs => 'unary_operator', rhs => [qw/!/], },
         { lhs => 'postfix_exp', rhs => [qw/primary_exp/], },
         { lhs => 'postfix_exp', rhs => [qw/postfix_exp lbracket exp rbracket/], },
         { lhs => 'postfix_exp', rhs => [qw/postfix_exp ( argument_exp_list )/], },
         { lhs => 'postfix_exp', rhs => [qw/postfix_exp ( )/], },
         { lhs => 'postfix_exp', rhs => [qw/postfix_exp . id/], },
         { lhs => 'postfix_exp', rhs => [qw/postfix_exp -> id/], },
         { lhs => 'postfix_exp', rhs => [qw/postfix_exp ++/], },
         { lhs => 'postfix_exp', rhs => [qw/postfix_exp --/], },
         { lhs => 'primary_exp', rhs => [qw/id/], },
         { lhs => 'primary_exp', rhs => [qw/constant/], },
         { lhs => 'primary_exp', rhs => [qw/string/], },
         { lhs => 'primary_exp', rhs => [qw/( exp )/], action => 'value2'},
         { lhs => 'argument_exp_list', rhs => [qw/assignment_exp/], min => 1, separator => 'comma', action => 'list', },
         { lhs => 'constant', rhs => [qw/int_const/], },
         { lhs => 'constant', rhs => [qw/char_const/], },
         { lhs => 'constant', rhs => [qw/float_const/], },
         { lhs => 'constant', rhs => [qw/enumeration_const/], },
           ];

my $grammar = Marpa::XS::Grammar->new({ start => 'translation_unit',
                                        actions => 'action',
                                        default_action => 'value',
                                        rules   => $rules});


$grammar->precompute();

my $recce = Marpa::XS::Recognizer->new( { grammar => $grammar, trace_terminals => 0} );

while(<>) {
	lexer($recce,$_);
}

my $value_ref = $recce->value;
my $value = $value_ref ? ${$value_ref} : 'No Parse';

#$Data::Dumper::Indent = 2;
print Dumper($value);

# my %done;
# for(@{$rules}) {
# 	my %h = %{$_};
# 	my $lhs = $h{lhs};
# 	for(@{$h{rhs}}) {
# 		#if($_ !~ /\W/)
# 		if(!$done{"\"$lhs\" -> \"$_\";\n"})
# 		{
# 			print "\"$lhs\" -> \"$_\";\n";
# 			$done{"\"$lhs\" -> \"$_\";\n"} = 1;
# 		}
# 	}
# }
