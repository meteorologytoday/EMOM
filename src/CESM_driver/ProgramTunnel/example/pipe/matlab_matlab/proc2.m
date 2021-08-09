addpath '../../src/matlab'

% Argument is the folder where fifos are ( here it is the same folder '.' )
ts = defaultTunnelSet('.')

% Reverse the flow direction! This is important. (X2Y => Y2X)
ts.reverseRole()


disp(ts.recvText());
ts.sendText('Happy! This_is_a_message_from_proc2.m');

disp(ts.recvText());
ts.sendText('Magical! This_is_the_second_message_from_proc2.m');

data = rand(5, 1);

% Get how many doubles we are going to recv
disp('Send an array: ');
disp(data);
ts.sendText(sprintf('%d', length(data)));
ts.sendBinary(data);

data = ts.recvBinary(length(data));
disp('Receive new array: ');
disp(data);



disp('Program finished.');
