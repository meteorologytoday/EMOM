addpath '../../src/matlab'


% Argument is the folder where fifos are ( here it is the same folder '.' )
ts = defaultTunnelSet('.')

% Need to reverse role in either matlab or fortran
ts.reverseRole()

% If fifos do not exist yet execute this line to create them, otherwise comment this line
% ts.mkTunnel()


ts.sendText('Amazing! This_is_a_message_from_proc1.m');
disp(ts.recvText());

ts.sendText('Not again! This_is_the_second_message_from_proc1.m');
disp(ts.recvText());


% Get how many doubles we are going to recv
n = str2num( ts.recvText() ); 
data = ts.recvBinary(n);

disp('Receive an array: ')
disp(data)

data = 50 * data;

disp('Multiply by 50 and send it back.')
ts.sendBinary(data);


disp('Program finished.')
