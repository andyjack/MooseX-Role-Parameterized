#!/usr/bin/env perl
package MooseX::Role::Parameterized;
use Moose (
    extends => { -as => 'moose_extends' },
    around => { -as => 'moose_around' },
    'confess',
);

use Carp 'croak';
use Moose::Role ();
moose_extends 'Moose::Exporter';

use MooseX::Role::Parameterized::Meta::Role::Parameterizable;

our $CURRENT_METACLASS;

__PACKAGE__->setup_import_methods(
    with_caller => ['parameter', 'role', 'method'],
    as_is       => ['has', 'with', 'extends', 'requires', 'excludes', 'augment', 'inner', 'before', 'after', 'around', 'super', 'override'],
);

sub parameter {
    my $caller = shift;
    my $names  = shift;

    $names = [$names] if !ref($names);

    for my $name (@$names) {
        Class::MOP::Class->initialize($caller)->add_parameter($name, @_);
    }
}

sub role {
    my $caller         = shift;
    my $role_generator = shift;
    Class::MOP::Class->initialize($caller)->role_generator($role_generator);
}

sub init_meta {
    my $self = shift;

    return Moose::Role->init_meta(@_,
        metaclass => 'MooseX::Role::Parameterized::Meta::Role::Parameterizable',
    );
}

# give role a (&) prototype
moose_around _make_wrapper => sub {
    my $orig = shift;
    my ($self, $caller, $sub, $fq_name) = @_;

    if ($fq_name =~ /::role$/) {
        return sub (&) { $sub->($caller, @_) };
    }

    return $orig->(@_);
};

sub has {
    confess "has must be called within the role { ... } block."
        unless $CURRENT_METACLASS;

    my $names = shift;
    $names = [$names] if !ref($names);

    for my $name (@$names) {
        $CURRENT_METACLASS->add_attribute($name, @_);
    }
}

sub method {
    confess "method must be called within the role { ... } block."
        unless $CURRENT_METACLASS;

    my $caller = shift;
    my $name   = shift;
    my $body   = shift;

    my $method = $CURRENT_METACLASS->method_metaclass->wrap(
        package_name => $caller,
        name         => $name,
        body         => $body,
    );

    $CURRENT_METACLASS->add_method($name => $method);
}

sub before {
    confess "before must be called within the role { ... } block."
        unless $CURRENT_METACLASS;

    my $code = pop @_;

    for (@_) {
        croak "Roles do not currently support "
            . ref($_)
            . " references for before method modifiers"
            if ref $_;
        $CURRENT_METACLASS->add_before_method_modifier($_, $code);
    }
}

sub after {
    confess "after must be called within the role { ... } block."
        unless $CURRENT_METACLASS;

    my $code = pop @_;

    for (@_) {
        croak "Roles do not currently support "
            . ref($_)
            . " references for after method modifiers"
            if ref $_;
        $CURRENT_METACLASS->add_after_method_modifier($_, $code);
    }
}

sub around {
    confess "around must be called within the role { ... } block."
        unless $CURRENT_METACLASS;

    my $code = pop @_;

    for (@_) {
        croak "Roles do not currently support "
            . ref($_)
            . " references for around method modifiers"
            if ref $_;
        $CURRENT_METACLASS->add_around_method_modifier($_, $code);
    }
}

sub with {
    confess "with must be called within the role { ... } block."
        unless $CURRENT_METACLASS;
    Moose::Util::apply_all_roles($CURRENT_METACLASS, @_);
}

sub requires {
    confess "requires must be called within the role { ... } block."
        unless $CURRENT_METACLASS;
    croak "Must specify at least one method" unless @_;
    $CURRENT_METACLASS->add_required_methods(@_);
}

sub excludes {
    confess "excludes must be called within the role { ... } block."
        unless $CURRENT_METACLASS;
    croak "Must specify at least one role" unless @_;
    $CURRENT_METACLASS->add_excluded_roles(@_);
}

# see Moose.pm for discussion
sub super {
    return unless $Moose::SUPER_BODY;
    $Moose::SUPER_BODY->(@Moose::SUPER_ARGS);
}

sub override {
    confess "override must be called within the role { ... } block."
        unless $CURRENT_METACLASS;

    my ($name, $code) = @_;
    $CURRENT_METACLASS->add_override_method_modifier($name, $code);
}

sub extends { croak "Roles do not currently support 'extends'" }

sub inner { croak "Roles cannot support 'inner'" }

sub augment { croak "Roles cannot support 'augment'" }

1;

