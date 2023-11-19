Fs=4000;
f=10;
t=0:1/Fs:0.1-1/Fs;
ep=sin(2*pi*t*f)';
data=randn(length(ep)*3,1) *0.01;
data(length(ep):length(ep)*2-1,1)=ep;
c=mepclassifier.ClassifierManager().classifier('uclassifier')
[s,e,p]=c.classify(data,4000);
figure,plot([data,p])
legend({'data','Background','stimulation artefact','EP'})