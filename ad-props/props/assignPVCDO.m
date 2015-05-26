function f = assignPVCDO(f, pvcdo, reg)
ntpvt = numel(reg.PVTINX);
if ntpvt == 1
    f.cO  = pvcdo(1, 3);
else
    f.cO  = pvcdo(reg.PVTNUM, 3);
end
f.BO     = @(po, varargin)BO(po, pvcdo, reg, varargin{:});
f.bO     = @(po, varargin)bO(po, pvcdo, reg, varargin{:});
f.BOxmuO = @(po, varargin)BOxmuO(po, pvcdo, reg, varargin{:});
end

function v = BO(po, pvcdo, reg, varargin)
pvtnum = getPVTNUM(po, reg, varargin{:});

por  = pvcdo(pvtnum,1); % ref pres
bor  = pvcdo(pvtnum,2); % ref fvf
co   = pvcdo(pvtnum,3); % compress
X = co.*(po-por);
v = bor.*exp(-X);
end

function v = bO(po, pvcdo, reg, varargin)
pvtnum = getPVTNUM(po, reg, varargin{:});

por  = pvcdo(pvtnum,1); % ref pres
bor  = pvcdo(pvtnum,2); % ref fvf
co   = pvcdo(pvtnum,3); % compress
X = co.*(po-por);
v = exp(X)./bor;
end

function v = BOxmuO(po, pvcdo, reg, varargin)
pvtnum = getPVTNUM(po, reg, varargin{:});

por  = pvcdo(pvtnum,1); % ref pres
bor  = pvcdo(pvtnum,2); % ref fvf
co   = pvcdo(pvtnum,3); % compress
muor = pvcdo(pvtnum,4); % ref visc
vbo  = pvcdo(pvtnum,5); % viscosibility
Y = (co-vbo).*(po-por);
v = bor.*muor.*exp(-Y);
end


function pvtnum= getPVTNUM(po, reg, varargin)
pvtinx = getRegMap(po, reg.PVTNUM, reg.PVTINX, varargin{:});

if(pvtinx{1}==':')
   pvtnum=ones(size(po));
   assert(numel(pvtinx)==1);
else
    pvtnum=nan(size(po));
    for i=1:numel(pvtinx)
       pvtnum(pvtinx{i})=i;
    end
end
end

