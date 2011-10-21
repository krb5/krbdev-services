#include "svn_pools.h"
#include "svn_cmdline.h"
#include "svn_error.h"
#include "svn_opt.h"
#include "svn_utf.h"
#include "svn_subst.h"
#include "svn_path.h"
#include "svn_config.h"
#include "svn_repos.h"
#include "svn_fs.h"
#include "svn_version.h"
#include "svn_props.h"

/* Version compatibility check */
static svn_error_t *
check_lib_versions(void)
{
  static const svn_version_checklist_t checklist[] =
    {
      { "svn_subr",  svn_subr_version },
      { "svn_repos", svn_repos_version },
      { "svn_fs",    svn_fs_version },
      { NULL, NULL }
    };

  SVN_VERSION_DEFINE(my_version);
  return svn_ver_check_list(&my_version, checklist);
}


static svn_error_t *
doit(const char *repospath, const char *txnname, const char *prop, const char *propval, apr_pool_t *pool)
{
    svn_repos_t *repos;
    svn_fs_txn_t *txn;
    SVN_ERR(svn_repos_open(&repos, repospath, pool));
    SVN_ERR(svn_fs_open_txn(&txn, svn_repos_fs(repos), txnname, pool));

    if (propval) {
        SVN_ERR(svn_fs_change_txn_prop(txn, prop, svn_string_create(propval, pool), pool));
    }
    else {
        svn_string_t *val;
        SVN_ERR(svn_fs_txn_prop(&val, txn, prop, pool));
        if (val) {
            printf("%s", val->data);
        }
    }

    return SVN_NO_ERROR;
  
}

int
my_svn_cmdline_handle_exit_error(svn_error_t *err,
                                 apr_pool_t *pool,
                                 const char *prefix)
{
  svn_handle_error2(err, stderr, FALSE, prefix);
  svn_error_clear(err);
  if (pool)
    svn_pool_destroy(pool);
  return EXIT_FAILURE;
}

int
main(int argc, const char *argv[])
{
    svn_error_t *err;
    apr_pool_t *pool;

    if (svn_cmdline_init("svntxnprop", stderr) != EXIT_SUCCESS)
        return EXIT_FAILURE;


    /* Check library versions */
    err = check_lib_versions();
    if (err)
        return my_svn_cmdline_handle_exit_error(err, pool, "svntxnprop: ");

    pool = svn_pool_create(NULL);

    /* Initialize the FS library. */
    err = svn_fs_initialize(pool);
    if (err)
        return my_svn_cmdline_handle_exit_error(err, pool, "svntxnprop: ");

    if (argc < 3) {
        fprintf(stderr, "usage: %s REPOSPATH TXN PROP [VAL]\n", argv[0]);
        svn_pool_destroy(pool);
        return EXIT_FAILURE;
    }

    err = doit(argv[1], argv[2], argv[3], argv[4], pool);
    if (err)
        return my_svn_cmdline_handle_exit_error(err, pool, "svntxnprop: ");


    return 0;
}

