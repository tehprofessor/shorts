#include "erl_nif.h"
#include "string.h"
#include "./wyhash.h"

#define MAX_BUF_LEN 4096
// There is zero reason for the magic seed number being
// what it is, but if we change it, all the hashes will
// change.
#define WYHASH_SEED_MAGIC_NUMBER_DONT_CHANGE 1024

static ERL_NIF_TERM
wyhash_hash(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {

    char key[MAX_BUF_LEN];
    unsigned long long keySize;
    unsigned long long keyHash;
    // Create the C string from our Erlang term
    if (enif_get_string(env, argv[0], key, sizeof(key), ERL_NIF_LATIN1) < 1) {
        return enif_make_badarg(env);
    }
    // Get the length of the string
    keySize = (unsigned long long) strlen(key);
    keyHash = wyhash(key, keySize, 1);

    return enif_make_long(env, keyHash);
};

static ErlNifFunc nif_funcs[] = {
    {"hash", 1, wyhash_hash}
};

ERL_NIF_INIT(Elixir.WyhashEx, nif_funcs, NULL, NULL, NULL, NULL)
