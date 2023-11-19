function dragRectangles(initialRectPositionXs,ax,fig,onChangeCallback,anchorResolution,rectPositionY,colors)
    % Drag for figure/uibased based graphics
    % [INPUT]
    % initialRectPositionXs array<double>: Initial x-positions of
    %   rectangles. size=(N,2). Each row is a rectangles start and stop on
    %   the x-axes. 
    % ax object:double: Axes of axifigure|matlab.ui.Figure on which plottting is
    %   performed.
    % fig object|double: The figure contaning ax. The defaut is [].
    % onChangeCallback function: Called with one argument which is updated 
    %   values of x-positions equivalent to initialRectPositionXs. The 
    %   function is called when dragging stops.
    % anchorResolution double: Used to determine the absolute width at the
    %   left or right edge of a rectangle considered to be part of the
    %   edge.
    % rectPositionY array<double>:2-element array specifying the y-
    %   coordinates [start,stop] of the rectangles.
    % colors cell<string|array<double>>: Cell of valid matlab colors. If
    %   the number of colors given is less the the number of rectangles, N,
    %   then the colors will repeat.

    if nargin<1
        initialRectPositionXs=[1,2;
                        2,3;
                        3,4;
                        4,5;
                        5,6];
    end

    if nargin<2
        fig=figure;
        ax=axes(fig);
        axis(ax,[0 10 0 10]);
        axis manual;
        hold on;
    end

    if nargin <3
        fig=[];
    end

    if nargin<4
        onChangeCallback=@(x) disp(x);
    end

    if nargin <5
        % TODO: determin this default value from the xdata of axes. 
        anchorResolution=2;
    end
    
    if nargin < 6
        rectPositionY=[-0.5,0.5];
    end

    if nargin<7
        % Colors
        colors={[1,0,1,0.3],[1,0,0,0.7],[0,0,1,0.6],[0,1,0,0.5],[1,1,0,0.4]};
    end


    % Visibility for uifigure
    if isempty(fig)
        fig=get(ax,'Parent');
    end

    if isa(fig,'matlab.ui.Figure')
        fig.HandleVisibility="on";
    end


    %
    numRectangles = size(initialRectPositionXs,1);

    adjInitialRectPositionXs=initialRectPositionXs;
    adjInitialRectPositionXs(:,2)=initialRectPositionXs(:,2)-initialRectPositionXs(:,1);

    
    
    
    
    % Create rectangles
    rectangles = createRectangles(numRectangles);
    
    % Initialize drag state variables
    isDragging = false;
    currentRectangle = 0;
    xOffset = 0;
    anchorPosition=[];% See getAnchorPosition
    
    % Set mouse button down and up event handlers
    set(gcf, 'WindowButtonDownFcn', @mouseButtonDown);
    set(gcf, 'WindowButtonUpFcn', @mouseButtonUp);
    
    % Update rectangle position while dragging
    set(gcf, 'WindowButtonMotionFcn', @mouseButtonMotion);
    
    function rectangles = createRectangles(numRectangles)
        rectangles = cell(1, numRectangles);

        y=[rectPositionY(1),rectPositionY(2)-rectPositionY(1)];
        
        colorIdx=0;
        for i = 1:numRectangles
            colorIdx=colorIdx+1;
            if colorIdx>length(colors),colorIdx=1;end
            x=adjInitialRectPositionXs(i,:);

            faceColor=[0.5,0.5,.5];
            if ismatrix(colors{colorIdx})
                faceColor=colors{colorIdx}(1:3);
            end
            faceColor(4)=0.3;%Alpha

            rectangleHandle = rectangle(ax,'Position', [x(1) y(1) x(2) y(2)],'LineWidth',2,'EdgeColor',colors{colorIdx},"FaceColor",faceColor);
            rectangles{i} = rectangleHandle;
        end
    end

    function mouseButtonDown(~, ~)
        rectangleHandles = rectangles;
        currentRectangle = find(cellfun(@(x) x == gco, rectangleHandles));
        
        if ~isempty(currentRectangle)
            isDragging = true;
            rectPosition = get(rectangleHandles{currentRectangle}, 'Position');
            currentPoint = get(gca, 'CurrentPoint');
            xOffset = rectPosition(1) - currentPoint(1, 1);
            anchorPosition=getAnchorPosition();
        end
    end

    function mouseButtonUp(~, ~)
        if isDragging
            isDragging = false;
            emitChanges();
        end
    end

    function mouseButtonMotion(~, ~)
        if isDragging

            
            switch(anchorPosition)
                case 'between'
                    moveRectanglWestEast();
                case 'west'
                    adjustRectangleWest();
                case 'east'
                    adjustRectangleEast();
                otherwise 
                    error('Unknown achorPosition, %s',anchorPos)
            end

            drawnow;
            
        end
    end
    function emitChanges()
        % Emit the current positions of the rectangles

        % Get the rectangles' current positions
        rectangleHandles = rectangles;
        xs=zeros(numRectangles,2);
        for i = 1:numRectangles
            rectPosition = get(rectangleHandles{i}, 'Position');

            % Adjust the rectangle positions
            xs(i,:)=[rectPosition(1),rectPosition(1)+rectPosition(3)];
        end

        % Call the callback with adjusted rectangle positions.
        onChangeCallback(xs);
    end
    function adjustRectangleEast()
        currentPoint = get(gca, 'CurrentPoint');
        rect=getCurrentRectangle();
        
        rectPos=rect.Position;
        rectLeft=rect.Position(1);
        rectRight=rectLeft+rect.Position(3);
        xPosOffset=currentPoint(1,1)-rectRight;

        rectPos(3)=rectPos(3)+xPosOffset;
        if rectPos(3) >=0
            rectangleHandles = rectangles;
            rectangleHandles{currentRectangle}.Position=rectPos;
        end
    end

    function adjustRectangleWest()
        currentPoint = get(gca, 'CurrentPoint');
        rect = getCurrentRectangle();
        
        rectPos = rect.Position;
        rectLeft = rect.Position(1);
        xPosOffset = currentPoint(1, 1) - rectLeft;
        
        rectPos(1) = rectPos(1) + xPosOffset;
        rectPos(3) = rectPos(3) - xPosOffset;
        
        if rectPos(3) >= 0
            rectangleHandles = rectangles;
            rectangleHandles{currentRectangle}.Position = rectPos;
        end
    end

    function moveRectanglWestEast()
        currentPoint = get(gca, 'CurrentPoint');
        newX = currentPoint(1, 1) + xOffset;
        newY = currentPoint(1, 2);
        
        rectangleHandles = rectangles;
        rectPosition = get(rectangleHandles{currentRectangle}, 'Position');
        rectPosition(1) = newX;%max(newX, 0); %Only move along x-axis
        rectangleHandles{currentRectangle}.Position = rectPosition;

    end

    function anchorPos= getAnchorPosition()
        % Determine the anchor position.
        % achorPos string: {east, west,between} 

        

        currentPoint = get(gca, 'CurrentPoint');
        rect=getCurrentRectangle();

        rectLeft=rect.Position(1);
        rectRight=rectLeft+rect.Position(3);

        anchorPos='between';
        if currentPoint(1,1)-rectLeft < anchorResolution
            anchorPos='west';
        elseif currentPoint(1,1)-rectRight > -anchorResolution
            anchorPos='east';
        end
        
    end

    function rect=getCurrentRectangle()
        % Return the current rctangle an an object.
        rectangleHandles = rectangles;
        rect= get(rectangleHandles{currentRectangle});
    end
end
