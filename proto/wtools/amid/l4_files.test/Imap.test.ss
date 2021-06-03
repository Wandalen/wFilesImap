( function _Imap_test_ss_()
{

'use strict';

if( typeof module !== 'undefined' )
{
  const _ = require( '../../../node_modules/Tools' );

  _.include( 'wTesting' );
  _.include( 'wResolver' );
  _.include( 'wCensorBasic' );

  require( '../l4_files/entry/Imap.ss' );
}

const _ = _global_.wTools;

// --
// context
// --

function onSuiteBegin( test )
{
  let context = this;
  context.suiteTempPath = _.fileProvider.path.tempOpen( _.fileProvider.path.join( __dirname, '../..' ), 'FileProviderImap' );
  context.assetsOriginalPath = _.path.join( __dirname, '_asset' );
}

//

function onSuiteEnd( test )
{
  let context = this;
  _.fileProvider.path.tempClose( context.suiteTempPath );
}

//

function providerMake()
{
  let context = this;

  let defaultCredentials =
  {
    login : 'user@domain.com',
    password : 'password',
    hostUri : '127.0.0.1:143',
    tls : false,
  };
  let cred;

  let config = _.censor.configRead();
  if( config !== null )
  cred = _.resolver.resolve({ selector : context.cred, src : config });
  if( cred === undefined || ( cred.login === undefined && cred.password === undefined ) )
  cred = defaultCredentials;

  let providers = Object.create( null );
  providers.effective = providers.imap = _.FileProvider.Imap( cred );
  providers.hd = _.FileProvider.HardDrive();
  providers.extract = _.FileProvider.Extract({ protocols : [ 'extract' ] });
  providers.system = _.FileProvider.System({ providers : [ providers.effective, providers.hd, providers.extract ] });

  // let provider = _.FileProvider.Extract({ protocols : [ 'current', 'second' ] });
  // let system = _.FileProvider.System({ providers : [ provider ] }); /* xxx : try without the system ? */
  // _.assert( system.defaultProvider === null );

  return providers;
}

// --
// tests
// --

function login( test )
{
  let context = this;
  let providers = context.providerMake();
  providers.effective.ready.then( () => providers.effective.unform() );
  providers.effective.ready.then( () => test.true( true ) );
  return providers.effective.ready;
}

//

function loginRetryOnFail( test )
{
  let credentials =
  {
    login : 'user1@domain.com',
    password : 'password',
    hostUri : '127.0.0.1:143',
    tls : false,
  };

  test.case = 'default number of attempts';
  var begin = _.time.now();
  test.shouldThrowErrorSync( () => _.FileProvider.Imap( credentials ) );
  var spent = ( _.time.now() - begin ) / 1000;
  test.ge( spent, 5 );

  test.case = 'not default number of attempts';
  var errCallback = ( err, arg ) =>
  {
    test.identical( arg, undefined );
    test.true( _.errIs( err ) );
    console.log( err.message );
    test.identical( _.strCount( err.message, '= Message of Error' ), 1 );
    test.identical( _.strCount( err.message, 'Authentication failed' ), 1 );
    test.identical( _.strCount( err.message, 'textCode : \'AUTHENTICATIONFAILED\'' ), 1 );
    test.identical( _.strCount( err.message, 'source : \'authentication\' Cannot connect to server' ), 1 );
    return null;
  };
  var begin = _.time.now();
  test.shouldThrowErrorSync( () =>
  {
    _.FileProvider.Imap( _.props.extend( null, credentials, { authRetryLimit : 6, authTimeOut : 10000 } ) );
  }, errCallback );
  var spent = ( _.time.now() - begin ) / 1000;
  test.ge( spent, 10 );
}

//

function dirRead( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'read root directory';
  providers.effective.dirMake( '/read' );
  var got = providers.effective.dirRead( '/' );
  var exp = [ 'Drafts', 'INBOX', 'Junk', 'Sent', 'Trash', 'read' ];
  test.true( _.longHasAll( got, exp ) );

  /* */

  test.case = 'read subdirectory';
  providers.effective.dirMake( '/read/1-new' );
  providers.effective.dirMake( '/read/2-contacted' );
  providers.effective.fileWrite( '/read/<$>', 'data' );
  var exp = [ '1-new', '2-contacted', '<1>' ];
  var got = providers.effective.dirRead( '/read' );
  test.true( _.longHasAll( got, exp ) );

  /* */

  test.case = 'read nested directory';
  providers.effective.fileWrite( '/read/1-new/<$>', 'data' );
  providers.effective.fileWrite( '/read/1-new/<$>', 'data' );
  providers.effective.fileWrite( '/read/1-new/<$>', 'data' );
  var got = providers.effective.dirRead( '/read/1-new' );
  test.ge( got.length, 3 );

  /* */

  test.case = 'read not existed directory';
  var got = providers.effective.dirRead( '/doesNotExists' );
  var exp = null;
  test.identical( got, exp );

  test.case = 'read not existed nested directory';
  var got = providers.effective.dirRead( '/file/does/not/exist' );
  var exp = null;
  test.identical( got, exp );

  /* */

  providers.effective.fileDelete( '/read' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileRead( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'read existed file, encoding - map';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var got = providers.effective.fileRead({ filePath : '/read/<1>', encoding : 'map' });
  var exp = [ 'attributes', 'parts', 'seqNo', 'header', 'attachments' ];
  test.identical( _.props.keys( got ), exp );
  providers.effective.filesDelete( '/read' );

  test.case = 'read existed file, encoding - utf8';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var got = providers.effective.fileRead( '/read/<1>' );
  var exp = data;
  test.equivalent( got, exp );
  providers.effective.filesDelete( '/read' );

  test.case = 'read not existed file, throwing - 0';
  var got = providers.effective.fileRead({ filePath : '/read/<999>', throwing : 0 });
  var exp = null;
  test.identical( got, exp );
  providers.effective.filesDelete( '/read' );

  /* */

  test.case = 'read not existed directory, throwing - 0';
  var got = providers.effective.fileRead({ filePath : '/hrx', throwing : 0 });
  var exp = null;
  test.identical( got, exp );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileReadWithOptionsAdvanced( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'advanced.structing - 0';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var advanced = { structing : 0 };
  var got = providers.effective.fileRead({ filePath : '/read/<1>', advanced, encoding : 'map' });
  var exp = [ 'attributes', 'parts', 'seqNo', 'header', 'attachments' ];
  test.identical( _.props.keys( got ), exp );
  test.true( !( 'struct' in got.attributes ) );
  test.true( 'uid' in got.attributes );
  providers.effective.filesDelete( '/read' );

  /* */

  test.case = 'withHeader - 0, encoding - map';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var advanced = { withHeader : 0 };
  var got = providers.effective.fileRead({ filePath : '/read/<1>', advanced, encoding : 'map' });
  var exp = [ 'attributes', 'parts', 'seqNo', 'attachments' ];
  test.identical( _.props.keys( got ), exp );
  providers.effective.filesDelete( '/read' );

  /* */

  test.case = 'withHeader - 0, encoding - utf8';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var advanced = { withHeader : 0 };
  var got = providers.effective.fileRead({ filePath : '/read/<1>', advanced, encoding : 'utf8' });
  var body = `"body" : "--__boundary__\\r\\nContent-Type: text/plain; charset=UTF-8\\r\\nContent-Transfer-Encoding: 7bit`
  + `\\r\\n\\r\\nsome text\\r\\n\\r\\n--__boundary__\\r\\n--__boundary__\\r\\nContent-Type: text/plain; charset=UTF-8`
  + `\\r\\nContent-Transfer-Encoding: 7bit\\r\\nContent-Disposition: attachment; filename=File.txt\\r\\n\\r\\ndata of text file`
  + `\\r\\n--__boundary__--\\r\\n"`;
  var exp =
`{
${ body },
"attachments" : [
{
"fileName" : "File.txt",
"encoding" : "utf8",
"size" : 17,
"data" : "data of text file"
}
]
}`;
  test.equivalent( got, exp );
  providers.effective.filesDelete( '/read' );

  /* */

  test.case = 'withBody - 0, encoding - utf8';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var advanced = { withBody : 0 };
  var got = providers.effective.fileRead({ filePath : '/read/<1>', advanced, encoding : 'utf8' });
  var exp =
`{
"header" : {
"from" : [ "user@domain.com" ],
"to" : [ "user@domain.org" ],
"subject" : [ "some subject" ],
"mime-version" : [ "1.0" ],
"content-type" :
[
"multipart/alternate; boundary=__boundary__"
]
},
"attachments" : [
{
"fileName" : "File.txt",
"encoding" : "utf8",
"size" : 17,
"data" : "data of text file"
}
]
}`;
  test.equivalent( got, exp );
  providers.effective.filesDelete( '/read' );

  /* */

  test.case = 'withTail - 0, encoding - utf8';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var advanced = { withTail : 0 };
  var got = providers.effective.fileRead({ filePath : '/read/<1>', advanced, encoding : 'utf8' });
  var body = `"body" : "--__boundary__\\r\\nContent-Type: text/plain; charset=UTF-8\\r\\nContent-Transfer-Encoding: 7bit`
  + `\\r\\n\\r\\nsome text\\r\\n\\r\\n--__boundary__\\r\\n--__boundary__\\r\\nContent-Type: text/plain; charset=UTF-8`
  + `\\r\\nContent-Transfer-Encoding: 7bit\\r\\nContent-Disposition: attachment; filename=File.txt\\r\\n\\r\\ndata of text file`
  + `\\r\\n--__boundary__--\\r\\n"`;
  var exp =
`{
"header" : {
"from" : [ "user@domain.com" ],
"to" : [ "user@domain.org" ],
"subject" : [ "some subject" ],
"mime-version" : [ "1.0" ],
"content-type" :
[
"multipart/alternate; boundary=__boundary__"
]
},
${ body }
}`;
  test.equivalent( got, exp );
  providers.effective.filesDelete( '/read' );

  /* */

  test.case = 'only withTail, structing - 0, encoding - utf8';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=File.txt

c29tZSB0ZXh0

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File2.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var advanced = { withHeader : 0, withBody : 0, structing : 0 };
  var got = providers.effective.fileRead({ filePath : '/read/<1>', advanced, encoding : 'utf8' });
  var exp =
`{
"attachments" : [
{
"fileName" : "File.txt",
"encoding" : "utf8",
"size" : 9,
"data" : "some text"
},
{
"fileName" : "File2.txt",
"encoding" : "utf8",
"size" : 17,
"data" : "data of text file"
}
]
}`;
  test.equivalent( got, exp );
  providers.effective.filesDelete( '/read' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function attachmentsGet( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'single attachment';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var got = providers.effective.attachmentsGet({ filePath : '/read/<1>' });
  var exp =
  {
    fileName : 'File.txt',
    encoding : '7bit',
    size : 17,
    data : 'data of text file',
  };
  test.identical( got[ 0 ], exp );
  providers.effective.fileDelete( '/read' );

  /* */

  test.case = 'multiple attachments';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=File2.txt

ZGF0YSBvZiB0ZXh0IGZpbGU=
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var got = providers.effective.attachmentsGet({ filePath : '/read/<1>' });
  var exp =
  [
    {
      fileName : 'File.txt',
      encoding : '7bit',
      size : 17,
      data : 'data of text file',
    },
    {
      fileName : 'File2.txt',
      encoding : 'base64',
      size : 24,
      data : BufferNode.from( 'ZGF0YSBvZiB0ZXh0IGZpbGU=', 'base64' ),
    },
  ];
  test.identical( got, exp );
  providers.effective.fileDelete( '/read' );

  /* */

  test.case = 'multiple attachments, decoding - 1, encoding - utf8';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=File2.txt

ZGF0YSBvZiB0ZXh0IGZpbGU=
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var got = providers.effective.attachmentsGet({ filePath : '/read/<1>', decoding : 1 });
  var exp =
  [
    {
      fileName : 'File.txt',
      encoding : 'utf8',
      size : 17,
      data : 'data of text file',
    },
    {
      fileName : 'File2.txt',
      encoding : 'utf8',
      size : 17,
      data : 'data of text file',
    },
  ];
  test.identical( got, exp );
  providers.effective.fileDelete( '/read' );

  /* */

  test.case = 'multiple attachments, decoding - 1, encoding - base64';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=File2.txt

ZGF0YSBvZiB0ZXh0IGZpbGU=
--__boundary__--
`;
  providers.effective.fileWrite( '/read/<$>', data );
  var got = providers.effective.attachmentsGet({ filePath : '/read/<1>', decoding : 1, encoding : 'base64' });
  var exp =
  [
    {
      fileName : 'File.txt',
      encoding : 'base64',
      size : 24,
      data : 'ZGF0YSBvZiB0ZXh0IGZpbGU=',
    },
    {
      fileName : 'File2.txt',
      encoding : 'base64',
      size : 24,
      data : 'ZGF0YSBvZiB0ZXh0IGZpbGU=',
    },
  ];
  test.identical( got, exp );
  providers.effective.fileDelete( '/read' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function statRead( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'stat of existed file';
  providers.effective.fileWrite( '/stat/<$>', 'data' );
  var got = providers.effective.statRead( '/stat/<1>' );
  test.identical( got.size, 4 );
  test.identical( got.isFile(), true );
  test.identical( got.isDir(), false );
  test.identical( got.isDirectory(), false );

  test.case = 'stat of existed nested directory';
  providers.effective.dirMake( '/stat/1-new' );
  var got = providers.effective.statRead( '/stat/1-new' );
  test.identical( got.size, null );
  test.identical( got.isFile(), false );
  test.identical( got.isDir(), true );
  test.identical( got.isDirectory(), true );

  /* */

  test.case = 'stat of not existed nested directory';
  var got = providers.effective.statRead({ filePath : '/stat/abc', throwing : 0 });
  test.identical( got, null );

  test.case = 'stat of not existed nested directory - 2 levels';
  var got = providers.effective.statRead({ filePath : '/stat/abc/abc', throwing : 0 });
  test.identical( got, null );

  /* */

  providers.effective.fileDelete( '/stat' );

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileExists( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'check existed directory';
  var got = providers.effective.fileExists( '/INBOX' );
  test.identical( got, true );

  test.case = 'check not existed directory';
  var got = providers.effective.fileExists( '/notExistedDirectory' );
  test.identical( got, false );

  test.case = 'check existed file';
  providers.effective.fileWrite( '/exists/<$>', 'data' );
  var got = providers.effective.fileExists( '/exists/<1>' );
  test.identical( got, true );
  providers.effective.fileDelete( '/exists' )

  test.case = 'check not existed file';
  var got = providers.effective.fileExists( '/INBOX/<999>' );
  test.identical( got, false );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileWrite( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'write file in existed directory';
  providers.effective.dirMake( '/write' );
  providers.effective.fileWrite( '/write/<$>', 'data' );
  var got = providers.effective.dirRead( '/write' );
  test.true( _.longHas( got, '<1>' ) );
  providers.effective.filesDelete( '/write' );

  test.case = 'write file in not existed directory';
  providers.effective.fileWrite( '/write/<$>', 'data' );
  var got = providers.effective.dirRead( '/write' );
  test.true( _.longHas( got, '<1>' ) );
  providers.effective.filesDelete( '/write' );

  test.case = 'write file with flags, string';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite({ filePath : '/write/<$>', data, advanced : { flags : 'Seen' } });
  var got = providers.effective.fileRead( '/write/<1>', 'map' );
  test.identical( got.attributes.flags, [ '\\Seen' ] );
  providers.effective.filesDelete( '/write' );

  test.case = 'write file with flags, array';
  var data =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=File.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite({ filePath : '/write/<$>', data, advanced : { flags : [ 'Seen', 'Flagged' ] } });
  var got = providers.effective.fileRead( '/write/<1>', 'map' );
  test.identical( got.attributes.flags, [ '\\Flagged', '\\Seen' ] );
  providers.effective.filesDelete( '/write' );

  /* */

  if( Config.debug )
  {
    test.case = 'wrong name of file';
    test.shouldThrowErrorSync( () => providers.effective.fileWrite( '/INBOX/<2>', 'data' ) );
  }

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileDelete( test )
{
  let context = this;
  let providers = context.providerMake();

  if( providers.effective.fileExists( '/delete' ) )
  providers.effective.fileDelete( '/delete' );

  /* */

  test.case = 'delete single file';
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  var got = providers.effective.dirRead( '/delete' );
  test.true( _.longHas( got, '<1>' ) );

  providers.effective.fileDelete( '/delete/<1>' );
  var got = providers.effective.dirRead( '/delete' );
  test.false( _.longHas( got, '<1>' ) );

  /* */

  test.case = 'delete single directory in root level';
  providers.effective.dirMake( '/delete' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [] );

  providers.effective.fileDelete( '/delete' );
  var got = providers.effective.dirRead( '/' );
  test.false( _.longHas( got, 'delete' ) );

  /* */

  test.case = 'delete single directory in root level, directory with file';
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ '<1>' ] );

  providers.effective.fileDelete( '/delete' );
  var got = providers.effective.dirRead( '/' );
  test.false( _.longHas( got, 'delete' ) );

  /* */

  test.case = 'delete single nested directory';
  providers.effective.dirMake( '/delete/new' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ 'new' ] );

  providers.effective.fileDelete( '/delete/new' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [] );

  /* */

  test.case = 'delete directory with nested directories';
  providers.effective.dirMake( '/delete/new/1/1' );
  providers.effective.dirMake( '/delete/new/2' );
  var got = providers.effective.dirRead( '/delete/new' );
  test.identical( got, [ '1', '2' ] );

  providers.effective.fileDelete( '/delete/new' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [] );

  /* */

  test.case = 'delete directory with nested directories and files';
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  providers.effective.fileWrite( '/delete/new/1/1/<$>', 'data' );
  providers.effective.fileWrite( '/delete/new/<$>', 'data' );
  providers.effective.dirMake( '/delete/new/2' );
  var got = providers.effective.dirRead( '/delete/new' );
  test.identical( got, [ '1', '2', '<1>' ] );

  providers.effective.fileDelete( '/delete' );
  var got = providers.effective.dirRead( '/' );
  test.false( _.longHas( got, 'delete' ) );

  /* */

  if( Config.debug )
  {
    test.case = 'wrong name of file';
    test.shouldThrowErrorSync( () => providers.effective.fileDelete( '/INBOX/<999>' ) );

    test.case = 'wrong name of directory';
    test.shouldThrowErrorSync( () => providers.effective.fileDelete( '/unknown' ) );

    test.case = 'delete builtin directory';
    test.shouldThrowErrorSync( () => providers.effective.fileDelete( '/INBOX' ) );
  }

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesDelete( test )
{
  let context = this;
  let providers = context.providerMake();

  if( providers.effective.fileExists( '/delete' ) )
  providers.effective.fileDelete( '/delete' );

  /* */

  test.case = 'delete a few directories in root level';
  providers.effective.dirMake( '/delete1' );
  providers.effective.dirMake( '/delete2' );
  providers.effective.dirMake( '/delete3' );
  var got = providers.effective.dirRead( '/' );
  test.true( _.longHasAll( got, [ 'delete1', 'delete2', 'delete3' ] ) );

  providers.effective.filesDelete({ filePath : [ '/delete1', '/delete3' ] });
  var got = providers.effective.dirRead( '/' );
  test.true( _.longHas( got, 'delete2' ) );
  providers.effective.fileDelete( '/delete2' );

  /* */

  test.case = 'delete a few files in root level directory';
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  providers.effective.fileWrite( '/delete/<$>', 'data' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ '<1>', '<2>', '<3>' ] );

  providers.effective.filesDelete({ filePath : [ '/delete/<1>', '/delete/<3>' ] });
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ '<2>' ] );
  providers.effective.fileDelete( '/delete' );

  /* */

  test.case = 'delete a few directories in root level directory';
  providers.effective.fileWrite( '/delete/1/a/<$>', 'data' );
  providers.effective.fileWrite( '/delete/2/a/<$>', 'data' );
  providers.effective.dirMake( '/delete/3' );
  providers.effective.dirMake( '/delete2' );
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ '1', '2', '3' ] );

  providers.effective.filesDelete({ filePath : [ '/delete/1', '/delete/3', '/delete2' ] });
  var got = providers.effective.dirRead( '/delete' );
  test.identical( got, [ '2' ] );
  var got = providers.effective.dirRead( '/' );
  test.false( _.longHas( got, 'delete2' ) );
  providers.effective.fileDelete( '/delete' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function dirMake( test )
{
  let context = this;
  let providers = context.providerMake();

  /* */

  test.case = 'create new directory';
  providers.effective.dirMake( '/make' );
  var got = providers.effective.dirRead( '/' );
  test.true( _.longHas( got, 'make' ) );
  providers.effective.fileDelete( '/make' );

  test.case = 'try to recreate existed directory';
  providers.effective.fileWrite( '/make/<$>', 'data' );
  providers.effective.dirMake( '/make' );
  var got = providers.effective.dirRead( '/make' );
  test.true( _.longHas( got, '<1>' ) );
  providers.effective.fileDelete( '/make' );

  test.case = 'create nested directory';
  providers.effective.dirMake( '/make/some' );
  var got = providers.effective.dirRead( '/' );
  test.true( _.longHas( got, 'make' ) );
  var got = providers.effective.dirRead( '/make' );
  test.identical( got, [ 'some' ] );
  providers.effective.fileDelete( '/make' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileRename( test )
{
  let context = this;
  let providers = context.providerMake();

  if( providers.effective.fileExists( '/rename' ) )
  providers.effective.fileDelete( '/rename' );

  /* */

  test.case = 'rename directory in root level';
  providers.effective.dirMake( '/toRename' );
  var got = providers.effective.dirRead( '/' );
  test.true( _.longHas( got, 'toRename' ) );

  providers.effective.fileRename( '/rename', '/toRename' );
  var got = providers.effective.dirRead( '/' );
  test.true( _.longHas( got, 'rename' ) );
  test.false( _.longHas( got, 'toRename' ) );
  providers.effective.fileDelete( '/rename' );

  /* */

  test.case = 'rename nested directory';
  providers.effective.dirMake( '/rename/toRename' );
  var got = providers.effective.dirRead( '/rename' );
  test.identical( got, [ 'toRename' ] );

  providers.effective.fileRename( '/rename/dst', '/rename/toRename' );
  var got = providers.effective.dirRead( '/rename' );
  test.identical( got, [ 'dst' ] );
  providers.effective.fileDelete( '/rename' );

  /* */

  test.case = 'rename directory with subdirectory and file';
  providers.effective.dirMake( '/rename/toRename/some' );
  providers.effective.fileWrite( '/rename/toRename/<$>', 'data' );
  var got = providers.effective.dirRead( '/rename' );
  test.identical( got, [ 'toRename' ] );

  providers.effective.fileRename( '/rename/dst', '/rename/toRename' );
  var got = providers.effective.dirRead( '/rename' );
  test.identical( got, [ 'dst' ] );
  var got = providers.effective.dirRead( '/rename/dst' );
  test.identical( got, [ '<1>', 'some' ] );
  providers.effective.fileDelete( '/rename' );

  /* */

  if( Config.debug )
  {
    test.case = 'srcPath has terminal filename';
    test.shouldThrowErrorSync( () => providers.effective.fileRename( '/rename/dst', '/rename/<1>' ) );

    test.case = 'dstPath has terminal filename';
    test.shouldThrowErrorSync( () => providers.effective.fileRename( '/rename/<1>', '/rename/src' ) );

    test.case = 'rename builtin directory';
    test.shouldThrowErrorSync( () => providers.effective.fileRename( '/rename', '/INBOX' ) );
  }

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function fileCopy( test )
{
  let context = this;
  let providers = context.providerMake();

  providers.effective.fileWrite( '/src/<$>', 'data' );

  /* */

  test.case = 'copy file into empty directory';
  providers.effective.dirMake( '/dst' );
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [] );

  providers.effective.fileCopy( '/dst/<$>', '/src/<1>' );
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>' ] );
  providers.effective.fileDelete( '/dst' );

  /* */

  test.case = 'copy file into directory with files';
  providers.effective.fileWrite( '/dst/<$>', 'data' );
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>' ] );

  providers.effective.fileCopy( '/dst/<$>', '/src/<1>' );
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>', '<2>' ] );
  providers.effective.fileDelete( '/dst' );

  /* */

  test.case = 'copy file into not existed directory, makingDirectory - 1';
  var got = providers.effective.dirRead( '/' );
  test.false( _.longHas( got, 'dst' ) );

  providers.effective.fileCopy({ dstPath : '/dst/<$>', srcPath : '/src/<1>', makingDirectory : 1 });
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>' ] );
  providers.effective.fileDelete( '/dst' );

  /* */

  test.case = 'src file does not exist, should throw error';
  test.shouldThrowErrorSync( () => providers.effective.fileCopy( '/dst/<$>', '/src/<999>' ) );

  test.case = 'copy file into not existed directory, makingDirectory - 0, should throw error';
  test.shouldThrowErrorSync( () => providers.effective.fileCopy( '/dst/<$>', '/src/<1>' ) );

  /* */

  providers.effective.fileDelete( '/src' );

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function areHardLinked( test )
{
  let context = this;
  let providers = context.providerMake();

  providers.effective.fileWrite( '/link1/<$>', 'data' );
  providers.effective.fileWrite( '/link2/<$>', 'data' );

  /* */

  test.case = 'two different paths, paths exist';
  var got = providers.effective.areHardLinked([ '/link1', '/link2' ]);
  test.identical( got, false );

  test.case = 'two different paths, paths exist';
  var got = providers.effective.areHardLinked([ '/link1/<1>', '/link2/<1>' ]);
  test.identical( got, false );

  test.case = 'two different paths, first path does not exist';
  var got = providers.effective.areHardLinked([ '/link3', '/link2' ]);
  test.identical( got, false );

  test.case = 'two different paths, second path does not exist';
  var got = providers.effective.areHardLinked([ '/link1', '/link3' ]);
  test.identical( got, false );

  test.case = 'two identical paths, paths exist';
  var got = providers.effective.areHardLinked([ '/link1', '/link1' ]);
  test.identical( got, true );

  test.case = 'two identical paths, paths exist';
  var got = providers.effective.areHardLinked([ '/link1/<1>', '/link1/<1>' ]);
  test.identical( got, true );

  test.case = 'two identical paths, paths do not exist';
  var got = providers.effective.areHardLinked([ '/link3', '/link3' ]);
  test.identical( got, true );

  test.case = 'two identical paths, paths do not exist';
  var got = providers.effective.areHardLinked([ '/link3/<1>', '/link3/<1>' ]);
  test.identical( got, true );

  /* */

  providers.effective.fileDelete( '/link1' );
  providers.effective.fileDelete( '/link2' );

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromImapToHdSingle( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple imap file to hard drive';
  var data = BufferNode.from( 'data' ).toString( 'base64' );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.system.filesReflect
  ({
    reflectMap : { '/src/<1>' : a.abs( '1.txt' ) },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.hd },
  });
  var got = providers.hd.filesFind( a.abs( '.' ) );
  test.identical( got.length, 1 );
  test.identical( got[ 0 ].relative, './1.txt' );
  var got = providers.hd.fileRead( a.abs( '1.txt' ) );
  test.identical( got, 'data' );
  providers.effective.fileDelete( '/src' );

  /* */

  test.case = 'write imap file with attachment to hard drive';
  var src =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=file.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/src/<$>', src );
  var dstPath = a.abs( '1.txt' );
  providers.system.filesReflect
  ({
    reflectMap : { '/src/<1>' : dstPath },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.hd },
  });
  var got = providers.hd.fileRead( dstPath );
  test.equivalent( got, src );
  providers.effective.fileDelete( '/src' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromImapToHdMultiple( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple imap file to hard drive';
  var data = BufferNode.from( 'data' ).toString( 'base64' );
  var data1 = BufferNode.from( 'data1' ).toString( 'base64' );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.effective.fileWrite( '/src/<$>', data1 );
  providers.system.filesReflect
  ({
    reflectMap : { '/src' : a.abs( '.' ) },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.hd },
  });
  var got = providers.hd.filesFind( a.abs( '.' ) );
  test.identical( got.length, 4 );
  test.identical( got[ 0 ].relative, './<1>' );
  test.identical( got[ 1 ].relative, './<2>' );
  var got = providers.hd.fileRead( a.abs( '<1>' ) );
  test.identical( got, 'data' );
  var got = providers.hd.fileRead( a.abs( '<4>' ) );
  test.identical( got, 'data1' );
  providers.effective.fileDelete( '/src' );

  /* */

  test.case = 'write imap file with attachment to hard drive';
  var data = BufferNode.from( 'data' ).toString( 'base64' );
  var src =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=file.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/src/<$>', src );
  providers.effective.fileWrite( '/src/<$>', src );
  providers.effective.fileWrite( '/src/<$>', src );
  providers.effective.fileWrite( '/src/<$>', data );
  var dstPath = a.abs( '.' );
  providers.system.filesReflect
  ({
    reflectMap : { '/src' : dstPath },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.hd },
  });
  var got = providers.hd.filesFind( a.abs( '.' ) );
  test.identical( got.length, 4 );
  test.identical( got[ 0 ].relative, './<1>' );
  test.identical( got[ 1 ].relative, './<2>' );
  var got = providers.hd.fileRead( a.abs( '<1>' ) );
  test.equivalent( got, src );
  var got = providers.hd.fileRead( a.abs( '<4>' ) );
  test.equivalent( got, 'data' );
  providers.effective.fileDelete( '/src' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromHdToImapSingle( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple hd file to imap';
  var srcPath = a.abs( '1.txt' );
  providers.hd.fileWrite( srcPath, 'data' );
  providers.system.filesReflect
  ({
    reflectMap : { [ srcPath ] : '/dst/<$>' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
  });
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>' ] );
  var got = providers.effective.fileRead({ filePath : '/dst/<1>', encoding : 'base64' });
  test.identical( got, 'data' );
  providers.effective.fileDelete( '/dst' );

  /* */

  test.case = 'write hd file with attachment to imap';
  var src =
  'From: user@domain.com\r\n'
  + 'To: user@domain.org\r\n'
  + 'Subject: some subjectg\r\n'
  + 'MIME-Version: 1.0\r\n'
  + '\r\n'
  + 'Content-Type: multipart/alternate; boundary=__boundary__\r\n'
  + '\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + '\r\n'
  + 'some text\r\n'
  + '\r\n'
  + '--__boundary__\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + 'Content-Disposition: attachment; filename=file.txt\r\n'
  + '\r\n'
  + 'data of text file\r\n'
  + '--__boundary__--\r\n'
  + '\r\n';
  var srcPath = a.abs( '<1>' );
  providers.hd.fileWrite( srcPath, src );
  providers.system.filesReflect
  ({
    reflectMap : { [ srcPath ] : '/dst/<$>' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
  });
  var got = providers.effective.fileRead( '/dst/<1>' );
  test.identical( got, src );
  providers.effective.fileDelete( '/dst' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromHdToImapMultiple( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple hd file to imap';
  providers.hd.fileWrite( a.abs( 'a.txt' ), 'data' );
  providers.hd.fileWrite( a.abs( 'b.txt' ), 'data' );
  providers.hd.fileWrite( a.abs( 'file.txt' ), 'data' );
  providers.hd.fileWrite( a.abs( '1.txt' ), 'data1' );
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( '.' ) ] : '/dst' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
    onDstName : ( name ) => name === '.' ? '.' : '<$>',
  });
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>', '<2>', '<3>', '<4>' ] );
  var got = providers.effective.fileRead({ filePath : '/dst/<1>', encoding : 'base64' });
  test.identical( got, 'data1' );
  var got = providers.effective.fileRead({ filePath : '/dst/<4>', encoding : 'base64' });
  test.identical( got, 'data' );
  providers.effective.filesDelete( '/dst' );
  providers.hd.filesDelete( a.abs( '.' ) );

  /* */

  test.case = 'write hd file with attachment to imap';
  var src =
  'From: user@domain.com\r\n'
  + 'To: user@domain.org\r\n'
  + 'Subject: some subjectg\r\n'
  + 'MIME-Version: 1.0\r\n'
  + '\r\n'
  + 'Content-Type: multipart/alternate; boundary=__boundary__'
  + '\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + '\r\n'
  + 'some text\r\n'
  + '\r\n'
  + '--__boundary__\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + 'Content-Disposition: attachment; filename=file.txt\r\n'
  + '\r\n'
  + 'data of text file\r\n'
  + '--__boundary__--\r\n'
  + '\r\n';
  providers.hd.fileWrite( a.abs( '<1>' ), src );
  providers.hd.fileWrite( a.abs( '<2>' ), src );
  providers.hd.fileWrite( a.abs( '<3>' ), src );
  providers.hd.fileWrite( a.abs( '<4>' ), 'data' );
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( '.' ) ] : '/dst' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
    onDstName : ( name ) => name === '.' ? '.' : '<$>',
  });
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>', '<2>', '<3>', '<4>' ] );
  var got = providers.effective.fileRead({ filePath : '/dst/<1>', encoding : 'utf8' });
  test.identical( got, src );
  var got = providers.effective.fileRead({ filePath : '/dst/<4>', encoding : 'utf8' });
  test.identical( got, 'data' );
  providers.effective.filesDelete( '/dst' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectBothSidesSingleFile( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );
  a.reflect();

  /* */

  test.case = 'file from hd to imap';
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( 'File.xml' ) ] : '/dst/<$>' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
  });
  var got = providers.effective.fileRead( '/dst/<1>', 'base64' );
  test.identical( got, providers.hd.fileRead( a.abs( 'File.xml' ) ) );
  providers.effective.fileDelete( '/dst' );

  test.case = 'file from imap to hd';
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( 'File.xml' ) ] : '/src/<$>' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
  });
  providers.system.filesReflect
  ({
    reflectMap : { '/src/<1>' : a.abs( 'Copy' ) },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.hd },
  });
  var got = providers.hd.fileRead( a.abs( 'Copy' ) );
  test.identical( got, providers.effective.fileRead( '/src/<1>', 'base64' ) );
  test.identical( got, providers.hd.fileRead( a.abs( 'File.xml' ) ) );
  providers.effective.fileDelete( '/src' );

  /* */

  test.case = 'file from hd to imap';
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( 'File.txt' ) ] : '/dst/<$>' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
  });
  var got = providers.effective.fileRead( '/dst/<1>', 'base64' );
  test.identical( got, providers.hd.fileRead( a.abs( 'File.txt' ) ) );
  providers.effective.fileDelete( '/dst' );

  test.case = 'file from imap to hd';
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( 'File.txt' ) ] : '/src/<$>' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
  });
  providers.system.filesReflect
  ({
    reflectMap : { '/src/<1>' : a.abs( 'Copy' ) },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.hd },
  });
  var got = providers.hd.fileRead( a.abs( 'Copy' ) );
  test.identical( got, providers.effective.fileRead( '/src/<1>', 'base64' ) );
  test.identical( got, providers.hd.fileRead( a.abs( 'File.txt' ) ) );
  providers.effective.fileDelete( '/src' );

  /* */

  test.case = 'reflect multiline file from imap to hd and back';
  var src =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=file.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/src/<$>', src );
  providers.system.filesReflect
  ({
    reflectMap : { '/src/<1>' : a.abs( '<1>' ) },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.hd },
  });
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( '<1>' ) ] : '/src/<$>' },
    src : { effectiveProvider : providers.hd },
    dst : { effectiveProvider : providers.effective },
  });
  var got = providers.effective.fileRead( '/src/<2>' );
  var exp = providers.effective.fileRead( '/src/<1>' );
  test.identical( got, exp );
  providers.effective.filesDelete( '/src' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromImapToExtractSingle( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple imap file to hard drive';
  var data = BufferNode.from( 'data' ).toString( 'base64' );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.system.filesReflect
  ({
    reflectMap : { '/src/<1>' : a.abs( '1.txt' ) },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.extract },
  });
  var got = providers.extract.filesFind( a.abs( '.' ) );
  test.identical( got.length, 1 );
  test.identical( got[ 0 ].relative, './1.txt' );
  var got = providers.extract.fileRead( a.abs( '1.txt' ) );
  test.identical( got, 'data' );
  providers.effective.fileDelete( '/src' );

  /* */

  test.case = 'write imap file with attachment to hard drive';
  var src =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=file.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/src/<$>', src );
  var dstPath = a.abs( '1.txt' );
  providers.system.filesReflect
  ({
    reflectMap : { '/src/<1>' : dstPath },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.extract },
  });
  var got = providers.extract.fileRead( dstPath );
  test.equivalent( got, src );
  providers.effective.fileDelete( '/src' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromImapToExtractMultiple( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple imap file to hard drive';
  var data = BufferNode.from( 'data' ).toString( 'base64' );
  var data1 = BufferNode.from( 'data1' ).toString( 'base64' );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.effective.fileWrite( '/src/<$>', data );
  providers.effective.fileWrite( '/src/<$>', data1 );
  providers.system.filesReflect
  ({
    reflectMap : { '/src' : a.abs( '.' ) },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.extract },
  });
  var got = providers.extract.filesFind( a.abs( '.' ) );
  test.identical( got.length, 4 );
  test.identical( got[ 0 ].relative, './<1>' );
  test.identical( got[ 1 ].relative, './<2>' );
  var got = providers.extract.fileRead( a.abs( '<1>' ) );
  test.identical( got, 'data' );
  var got = providers.extract.fileRead( a.abs( '<4>' ) );
  test.identical( got, 'data1' );
  providers.effective.fileDelete( '/src' );

  /* */

  test.case = 'write imap file with attachment to hard drive';
  var data = BufferNode.from( 'data' ).toString( 'base64' );
  var src =
`From: user@domain.com
To: user@domain.org
Subject: some subject
MIME-Version: 1.0
Content-Type: multipart/alternate; boundary=__boundary__

--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

some text

--__boundary__
--__boundary__
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename=file.txt

data of text file
--__boundary__--
`;
  providers.effective.fileWrite( '/src/<$>', src );
  providers.effective.fileWrite( '/src/<$>', src );
  providers.effective.fileWrite( '/src/<$>', src );
  providers.effective.fileWrite( '/src/<$>', data );
  var dstPath = a.abs( '.' );
  providers.system.filesReflect
  ({
    reflectMap : { '/src' : dstPath },
    src : { effectiveProvider : providers.effective },
    dst : { effectiveProvider : providers.extract },
  });
  var got = providers.extract.filesFind( a.abs( '.' ) );
  test.identical( got.length, 4 );
  test.identical( got[ 0 ].relative, './<1>' );
  test.identical( got[ 1 ].relative, './<2>' );
  var got = providers.extract.fileRead( a.abs( '<1>' ) );
  test.equivalent( got, src );
  var got = providers.extract.fileRead( a.abs( '<4>' ) );
  test.equivalent( got, 'data' );
  providers.effective.fileDelete( '/src' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromExtractToImapSingle( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple extract file to imap';
  var srcPath = a.abs( '1.txt' );
  providers.extract.fileWrite( srcPath, 'data' );
  providers.system.filesReflect
  ({
    reflectMap : { [ srcPath ] : '/dst/<$>' },
    src : { effectiveProvider : providers.extract },
    dst : { effectiveProvider : providers.effective },
  });
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>' ] );
  var got = providers.effective.fileRead({ filePath : '/dst/<1>', encoding : 'base64' });
  test.identical( got, 'data' );
  providers.effective.fileDelete( '/dst' );

  /* */

  test.case = 'write extract file with attachment to imap';
  var src =
  'From: user@domain.com\r\n'
  + 'To: user@domain.org\r\n'
  + 'Subject: some subjectg\r\n'
  + 'MIME-Version: 1.0\r\n'
  + '\r\n'
  + 'Content-Type: multipart/alternate; boundary=__boundary__'
  + '\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + '\r\n'
  + 'some text\r\n'
  + '\r\n'
  + '--__boundary__\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + 'Content-Disposition: attachment; filename=file.txt\r\n'
  + '\r\n'
  + 'data of text file\r\n'
  + '--__boundary__--\r\n'
  + '\r\n';
  var srcPath = a.abs( '<1>' );
  providers.extract.fileWrite( srcPath, src );
  providers.system.filesReflect
  ({
    reflectMap : { [ srcPath ] : '/dst/<$>' },
    src : { effectiveProvider : providers.extract },
    dst : { effectiveProvider : providers.effective },
  });
  var got = providers.effective.fileRead( '/dst/<1>' );
  test.equivalent( got, src );
  providers.effective.fileDelete( '/dst' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

//

function filesReflectFromExtractToImapMultiple( test )
{
  let context = this;
  let providers = context.providerMake();
  let a = test.assetFor( 'basic' );

  /* */

  test.case = 'write simple extract file to imap';
  providers.extract.fileWrite( a.abs( 'a.txt' ), 'data' );
  providers.extract.fileWrite( a.abs( 'b.txt' ), 'data' );
  providers.extract.fileWrite( a.abs( 'file.txt' ), 'data' );
  providers.extract.fileWrite( a.abs( '1.txt' ), 'data1' );
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( '.' ) ] : '/dst' },
    src : { effectiveProvider : providers.extract },
    dst : { effectiveProvider : providers.effective },
    onDstName : ( name ) => name === '.' ? '.' : '<$>',
  });
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>', '<2>', '<3>', '<4>' ] );
  var got = providers.effective.fileRead({ filePath : '/dst/<1>', encoding : 'base64' });
  test.identical( got, 'data1' );
  var got = providers.effective.fileRead({ filePath : '/dst/<4>', encoding : 'base64' });
  test.identical( got, 'data' );
  providers.effective.fileDelete( '/dst' );
  providers.extract.filesDelete( a.abs( '.' ) );

  /* */

  test.case = 'write extract file with attachment to imap';
  var data = BufferNode.from( 'data' ).toString( 'base64' );
  var src =
  'From: user@domain.com\r\n'
  + 'To: user@domain.org\r\n'
  + 'Subject: some subjectg\r\n'
  + 'MIME-Version: 1.0\r\n'
  + '\r\n'
  + 'Content-Type: multipart/alternate; boundary=__boundary__'
  + '\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + '\r\n'
  + 'some text\r\n'
  + '\r\n'
  + '--__boundary__\r\n'
  + '--__boundary__\r\n'
  + 'Content-Type: text/plain; charset=UTF-8\r\n'
  + 'Content-Transfer-Encoding: 7bit\r\n'
  + 'Content-Disposition: attachment; filename=file.txt\r\n'
  + '\r\n'
  + 'data of text file\r\n'
  + '--__boundary__--\r\n'
  + '\r\n';
  providers.extract.fileWrite( a.abs( '<1>' ), src );
  providers.extract.fileWrite( a.abs( '<2>' ), src );
  providers.extract.fileWrite( a.abs( '<3>' ), src );
  providers.extract.fileWrite( a.abs( '<4>' ), data );
  providers.system.filesReflect
  ({
    reflectMap : { [ a.abs( '.' ) ] : '/dst' },
    src : { effectiveProvider : providers.extract },
    dst : { effectiveProvider : providers.effective },
    onDstName : ( name ) => name === '.' ? '.' : '<$>',
  });
  var got = providers.effective.dirRead( '/dst' );
  test.identical( got, [ '<1>', '<2>', '<3>', '<4>' ] );
  var got = providers.effective.fileRead({ filePath : '/dst/<1>', encoding : 'utf8' });
  test.identical( got, src );
  var got = providers.effective.fileRead({ filePath : '/dst/<4>', encoding : 'base64' });
  test.identical( got, 'data' );
  providers.effective.fileDelete( '/dst' );

  /* */

  providers.effective.ready.finally( () => providers.effective.unform() );
  return providers.effective.ready;
}

// --
// declare
// --

const Proto =
{

  name : 'Tools.files.fileProvider.Imap',
  silencing : 1,
  enabled : 1,
  routineTimeOut : 60000,

  onSuiteBegin,
  onSuiteEnd,

  context :
  {
    providerMake,
    suiteTempPath : null,
    assetsOriginalPath : null,
    cred :
    {
      login : 'about/email.login',
      password : 'about/email.password',
      hostUri : 'about/email.imap',
      tls : 'about/email.tls',
    }
  },

  tests :
  {

    login,
    loginRetryOnFail,

    dirRead,

    fileRead,
    fileReadWithOptionsAdvanced,

    attachmentsGet,
    statRead,
    fileExists,

    fileWrite,
    fileDelete,
    filesDelete,
    dirMake,

    fileRename,
    fileCopy,

    areHardLinked,

    //

    filesReflectFromImapToHdSingle,
    filesReflectFromImapToHdMultiple,
    filesReflectFromHdToImapSingle,
    filesReflectFromHdToImapMultiple,
    filesReflectBothSidesSingleFile,

    filesReflectFromImapToExtractSingle,
    filesReflectFromImapToExtractMultiple,
    filesReflectFromExtractToImapSingle,
    filesReflectFromExtractToImapMultiple,

  },

}

//

const Self = wTestSuite( Proto )
if( typeof module !== 'undefined' && !module.parent )
wTester.test( Self.name );

})();
