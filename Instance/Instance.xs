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

MODULE = AI::DecisionTree::Instance         PACKAGE = AI::DecisionTree::Instance

PROTOTYPES: DISABLE

Instance *
new_struct (class, result, values_ref)
    char * class
    int    result
    SV *   values_ref
  CODE:
    {
      Instance* instance = malloc(sizeof(Instance));
      AV* values = (AV*) SvRV(values_ref);
      int i;
    
      instance->result = result;
      instance->num_values = 1 + av_len(values);
      instance->values = malloc(instance->num_values * sizeof(int));
    
      for(i=0; i<instance->num_values; i++) {
        instance->values[i] = (int) SvIV( *av_fetch(values, i, 0) );
      }
    
      RETVAL = instance;
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
value_int (instance, attribute)
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

int
result_int (instance)
    Instance *  instance
  CODE:
    {
      RETVAL = instance->result;
    }
  OUTPUT:
    RETVAL

void
DESTROY (instance)
    Instance *  instance
  PPCODE:
    {
      free(instance->values);
      free(instance);
    }

