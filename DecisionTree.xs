#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

typedef struct {
  int result;
  int num_values;
  int *values;
} Instance;

MODULE = AI::DecisionTree         PACKAGE = AI::DecisionTree

PROTOTYPES: DISABLE

SV *
_instance (self, values_r, result)
    SV *   self
    SV *   values_r
    int    result
  CODE:
    {
      int i;
      Instance* instance;
      AV* values = (AV*) SvRV(values_r);

      New(0, instance, 1, Instance);
      instance->result = result;
      instance->num_values = 1 + av_len(values);
      instance->values = malloc(instance->num_values * sizeof(int));

      for(i=0; i<instance->num_values; i++) {
        instance->values[i] = (int) SvIV( *av_fetch(values, i, 0) );
      }

      RETVAL = sv_setref_pv(newSViv(0), NULL, (void *)instance);
    }
  OUTPUT:
    RETVAL

int
_result_int (instance)
    Instance *  instance
  CODE:
    {
      RETVAL = instance->result;
    }
  OUTPUT:
    RETVAL

void
_set_value (instance, attribute, value)
    Instance*   instance
    int         attribute
    int         value
  PPCODE:
    {
      int *new_values;
      int i;
    
      if (attribute >= instance->num_values) {
        if (!value) return; /* Nothing to do */
        
        printf("Expanding from %d to %d places\n", instance->num_values, attribute);
        new_values = realloc(instance->values, attribute * sizeof(int));
        if (!new_values)
          croak("Couldn't grab new memory to expand instance");
        
        for (i=instance->num_values; i<attribute-1; i++)
          new_values[i] = 0;
        free(instance->values);
        instance->values = new_values;
        instance->num_values = 1 + attribute;
      }
    
      instance->values[attribute] = value;
    }

int
_value_int (instance, attribute)
    Instance *  instance
    int         attribute
  CODE:
    {
      if (attribute >= instance->num_values) {
        RETVAL = 0;
      }
      else {
        RETVAL = instance->values[attribute];
      }
    }
  OUTPUT:
    RETVAL

void
_tally (self, instances_r, tallies_r, totals_r, attr)
    SV *   self
    SV *   instances_r
    SV *   tallies_r
    SV *   totals_r
    int    attr
  CODE:
    {
      AV *instances = (AV*) SvRV(instances_r);
      HV *tallies   = (HV*) SvRV(tallies_r);
      HV *totals    = (HV*) SvRV(totals_r);
      I32 top = av_len(instances);
      
      I32 i, v;
      SV **instance_r, **hash_entry, **sub_hash_entry;
      Instance *instance;
      
      for (i=0; i<=top; i++) {
	instance_r = av_fetch(instances, i, 0);
	instance = (Instance *) SvIV(SvRV(*instance_r));
	v = instance->num_values < attr ? 0 : instance->values[attr];
	if (!v) continue;
	
	/* $totals{$v}++ */
	hash_entry = hv_fetch(totals, (char *)&v, sizeof(I32), 1);
	if (!SvIOK(*hash_entry)) sv_setiv(*hash_entry, 0);
	sv_setiv( *hash_entry, 1+SvIV(*hash_entry) );
	
	/* $tallies{$v}{$_->result_int}++ */
	hash_entry = hv_fetch(tallies, (char *)&v, sizeof(I32), 0);
	
	if (!hash_entry) {
	  hash_entry = hv_store(tallies, (char *)&v, sizeof(I32), newRV_noinc((SV*) newHV()), 0);
	}
	
	sub_hash_entry = hv_fetch((HV*) SvRV(*hash_entry), (char *)&(instance->result), sizeof(int), 1);
	if (!SvIOK(*sub_hash_entry)) sv_setiv(*sub_hash_entry, 0);
	sv_setiv( *sub_hash_entry, 1+SvIV(*sub_hash_entry) );
      }
	/*  Old code:
      foreach (@$instances) {
	my $v = $_->value_int($all_attr->{$attr});
	next unless $v;
	$totals{ $v }++;
	$tallies{ $v }{ $_->result_int }++;
      }
	*/
    }
