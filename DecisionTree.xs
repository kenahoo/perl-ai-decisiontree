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
