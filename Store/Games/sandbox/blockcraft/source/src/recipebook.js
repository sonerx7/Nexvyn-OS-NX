import { recipesForGrid,prepareRecipe } from './crafting.js';
import { drawIcon,itemName } from './hud.js';
export class RecipeBook {
  constructor(){this.open=false;this.selected=0;this.page=0;this.message='';this.onlyAvailable=false;}
  toggle(){this.open=!this.open;this.message='';}
  items(invui) {
    const inv=invui.game.inventory;
    if(!this.cached || this.cached.version!==inv.version || this.cached.width!==invui.gridW) {
      const all=recipesForGrid(invui.gridW);
      this.cached={version:inv.version,width:invui.gridW,all,available:all.filter(r=>prepareRecipe(r,inv.slots))};
    }
    return this.onlyAvailable?this.cached.available:this.cached.all;
  }
  apply(invui){
    if(invui.grid.some(Boolean)){this.message=TR('book.empty_grid');return false;}
    const recipe=this.items(invui)[this.selected];if(!recipe)return false;
    const plan=prepareRecipe(recipe,invui.game.inventory.slots);
    if(!plan){this.message=TR('book.missing');return false;}
    invui.game.inventory.slots=plan.slots;invui.grid=plan.grid;invui.game.inventory.changed();
    this.open=false;return true;
  }
  draw(w,h,invui){
    const k=Math.min(w/800,h/520),pw=Math.min(w-20,790*k),ph=Math.min(h-20,500*k),x=(w-pw)/2,y=(h-ph)/2;
    gfx.color('#000000A0');gfx.rect(0,0,w,h);
    gfx.color('#C6C6C6');gfx.rect(x,y,pw,ph,0);gfx.color('#FFFFFF');gfx.rect(x+3,y+3,pw-6,3);
    gfx.color('#242424');gfx.text(TR('book.title'),x+16*k,y+14*k,22*k,'bold');
    const toggleX=x+384*k,toggleY=y+17*k;
    gfx.color(this.onlyAvailable?'#536D42':'#777777');gfx.rect(toggleX,toggleY,360*k,27*k,0);
    gfx.color('#FFFFFF');gfx.text(TR(this.onlyAvailable?'book.available':'book.all'),toggleX,toggleY+5*k,13*k,'bold','center',360*k);
    if(ui.hit('recipe:filter',toggleX,toggleY,360*k,27*k).clicked||input.pressed('y')){this.onlyAvailable=!this.onlyAvailable;this.selected=0;}
    const items=this.items(invui);this.selected=Math.min(Math.max(0,this.selected),Math.max(0,items.length-1));
    if(items.length&&input.pressed('down'))this.selected=(this.selected+1)%items.length;
    if(items.length&&input.pressed('up'))this.selected=(this.selected-1+items.length)%items.length;
    this.page=Math.floor(this.selected/8);
    for(let row=0;row<8;row++){
      const index=this.page*8+row;if(index>=items.length)break;
      const ry=y+(54+row*42)*k,on=index===this.selected;
      gfx.color(on?'#657A54':'#969696');gfx.rect(x+14*k,ry,355*k,37*k,0);
      drawIcon(items[index].id,x+20*k,ry+3*k,30*k);
      gfx.color('#FFFFFF');gfx.text(itemName(items[index].id),x+58*k,ry+9*k,15*k,'bold');
      if(ui.hit('recipe:'+index,x+14*k,ry,355*k,37*k).clicked)this.selected=index;
    }
    const recipe=items[this.selected];
    if(!items.length){gfx.color('#4A4A4A');gfx.wrap(TR('book.none'),x+20*k,y+100*k,340*k,16*k,'sans');}
    if(recipe){
      const cell=44*k,gx=x+420*k,gy=y+88*k;
      for(let i=0;i<recipe.cells.length;i++){
        const xx=gx+(i%invui.gridW)*cell,yy=gy+Math.floor(i/invui.gridW)*cell;
        gfx.color('#555555');gfx.rect(xx,yy,cell-2,cell-2,0);gfx.color('#8B8B8B');gfx.rect(xx+3,yy+3,cell-7,cell-7,0);
        if(recipe.cells[i])drawIcon(recipe.cells[i][Math.floor(invui.app.screens.t)%recipe.cells[i].length],xx+4,yy+4,cell-9);
      }
      drawIcon(recipe.id,gx+18*k,gy+155*k,55*k);
      gfx.color('#303030');gfx.text('× '+recipe.count,gx+84*k,gy+176*k,20*k,'bold');
      const bx=gx-4*k,by=y+332*k;gfx.color('#536D42');gfx.rect(bx,by,290*k,38*k,0);
      gfx.color('#FFFFFF');gfx.text(TR('book.fill'),bx,by+10*k,15*k,'bold','center',290*k);
      if(ui.hit('recipe:fill',bx,by,290*k,38*k).clicked||input.pressed('a'))this.apply(invui);
    }
    for(const [label,dx,action] of [['‹',18,()=>this.selected=(this.selected-8+items.length)%items.length],['›',315,()=>this.selected=(this.selected+8)%items.length],['×',730,()=>this.open=false]]){
      const by=y+ph-58*k,bx=x+dx*k;gfx.color('#626262');gfx.rect(bx,by,43*k,36*k,0);
      gfx.color('#FFFFFF');gfx.text(label,bx,by+5*k,23*k,'bold','center',43*k);
      if(ui.hit('recipe:nav:'+dx,bx,by,43*k,36*k).clicked&&(items.length||dx===730))action();
    }
    gfx.color('#6D2929');gfx.wrap(this.message||TR('book.hint'),x+384*k,y+ph-78*k,380*k,13*k,'sans');
  }
}
