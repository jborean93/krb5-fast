# Kerberos FAST Testing

Designed to test how to setup FAST armouring for Kerberos authentication on Linux.
To set this environment up run the following:

```bash
# Setup the virtual machine in either Libvirt or VirtualBox
vagrant up

# Configure the virtual machines and get them ready for the tests
ansible-playbook main.yml -vv
```

This will set up an environment with 3 hosts

* `DC01.fast.test` - Domain Controller
* `WIN.fast.test` - Windows Server 2022 host joined to the domain
* `LINUX.fast.test` - CentOS 8 Stream host with krb5 configured

The hosts have a local account `vagrant` with the password of `vagrant`.
There is also a domain account `fast@FAST.TEST` with the password `Password01`.

Use `vagrant ssh LINUX` to SSH into the Linux box, substitute `LINUX` with `DC01` or `WIN` to also SSH into the respective Windows boxes.

When on the Linux host you can verify that doing a kinit fails when using it with just password authentication.

```bash
kinit fast@FAST.TEST
```

> kinit: KDC policy rejects request while getting initial credentials

To get the TGT with FAST armouring enforced the `-T` argument must be used by `kinit` to armour the request with.
The `-T` argument takes in the path to a credential cache (CC) which based on the policies you can generate from the computer account keytab.
This looks like:

```bash
KRB5CCNAME=armour.cc kinit -k -t /etc/linux.keytab host/linux.fast.test@FAST.TEST
echo "Password01" | kinit -T armour.cc fast@FAST.TEST
klist

# Verify you can use the TGT to get a service ticket
kvno host/win.fast.test@FAST.TEST
```

It looks like Microsoft AD does not enforce armouring for machine accounts which is why the original `kinit` for the machine account works.
The code that generates the keytab must be done on a machine account in AD as using a user principal causes the `kinit` stage to fail due to the policy rejecting the un armoured authentication.

## How to Acquire a Credential in Python

To replicate this in the MIT krb5 API you can install [pykrb5](https://github.com/jborean93/pykrb5) and [gssapi](https://github.com/pythongssapi/python-gssapi) which expose a nice managed layer to the krb5/gssapi API with:

```bash
python3 -m venv krb5-venv
source krb5-venv/bin/activate
python -m pip install gssapi krb5
```

From there the following code replicates the behaviour of `kinit` with FAST armouring:

```python
import copy
import krb5

ctx = krb5.init_context()

# kinit with host keytab
armour_kt = krb5.kt_resolve(ctx, b"/etc/linux.keytab")
armour_kt_entry = list(armour_kt)[0]
armour_princ = copy.copy(armour_kt_entry.principal)

init_opt = krb5.get_init_creds_opt_alloc(ctx)
armour_cred = krb5.get_init_creds_keytab(ctx, armour_princ, init_opt, keytab=armour_kt)

armour_cc = krb5.cc_new_unique(ctx, b"MEMORY")
krb5.cc_initialize(ctx, armour_cc, armour_princ)
krb5.cc_store_cred(ctx, armour_cc, armour_cred)

# kinit for user with FAST armour
princ = krb5.parse_name_flags(ctx, b"fast@FAST.TEST")

init_opt = krb5.get_init_creds_opt_alloc(ctx)
krb5.get_init_creds_opt_set_canonicalize(init_opt, True)
krb5.get_init_creds_opt_set_fast_flags(ctx, init_opt, krb5.FastFlags.required)
krb5.get_init_creds_opt_set_fast_ccache(ctx, init_opt, armour_cc)

cred = krb5.get_init_creds_password(ctx, princ, init_opt, password=b"Password01")

# Can be placed in a FILE or other type as desired
mem_ccache = krb5.cc_new_unique(ctx, b"MEMORY")
krb5.cc_initialize(ctx, mem_ccache, princ)
krb5.cc_store_cred(ctx, mem_ccache, cred)
```

If you wish to then use the credential in GSSAPI run the following Python code afterwards:

```python
import gssapi
import gssapi.raw

kerberos = gssapi.OID.from_int_seq("1.2.840.113554.1.2.2")
kerb_user = gssapi.Name("fast@FAST.TEST", name_type=gssapi.NameType.user)

# Load the ccache into a GSSAPI Credential
ccache_name = mem_ccache.name or b""
if mem_ccache.cache_type:
    ccache_name = mem_ccache.cache_type + b":" + ccache_name

gssapi_cred = gssapi.raw.acquire_cred_from(
    {b"ccache": ccache_name},
    name=kerb_user,
    mechs=[kerberos],
    usage="initiate",
).creds

# Use the GSSAPI credential to create the client context
ctx = gssapi.SecurityContext(
    creds=gssapi_cred,
    usage="initiate",
    name=gssapi.Name("host@win.fast.test", name_type=gssapi.NameType.hostbased_service),
    mech=kerberos,
)

# Generate the Kerberos token to start the exchange
token = ctx.step()
```

What still needs to be figured out:

* What is the krb5 API for Heimdal for FAST armouring - does it even support it?
* Is there a better way to create the "machine" ccache to use with armouring automatically
* Is there a config entry in `krb5.conf` that can have it automatically use a specific ccache for armouring
* Is it possible to utilise anonymous authentication for armouring
